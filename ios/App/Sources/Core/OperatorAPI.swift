import Foundation
import AgentGateway

// MARK: - Models

struct HermesChatMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable { case user, hermes, system }
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date

    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
    }
}

struct AgentSessionInfo: Identifiable, Equatable, Sendable {
    let key: String
    var label: String
    var status: String
    var updatedAt: Date?
    var lastMessage: String?

    var id: String { key }
}

struct TaskSpec: Sendable {
    var prompt: String
    var repo: String?
    var label: String?
}

enum OperatorAgentEvent: Sendable {
    /// Streaming reply progress. `cumulative` is the full assistant snapshot when
    /// the gateway sends one; `delta` is the incremental chunk (protocol v4).
    case replyDelta(sessionKey: String, runID: String?, cumulative: String?, delta: String?)
    case replyFinal(sessionKey: String, runID: String?, text: String)
    case replyFailed(sessionKey: String, runID: String?, message: String)
    case sessionsChanged
}

/// Canonical session keys look like `agent:main:main`; requests may use the raw
/// tail (`main`). Events carry the canonical form, so match either way.
func sessionKeysMatch(_ a: String, _ b: String) -> Bool {
    if a == b { return true }
    return a.hasSuffix(":" + b) || b.hasSuffix(":" + a)
}

// MARK: - Wire methods

/// Gateway RPC names used by the operator connection, isolated here so protocol
/// drift only touches this file.
enum OperatorMethod {
    static let chatSend = "chat.send"
    static let chatAbort = "chat.abort"
    static let sessionsList = "sessions.list"
    static let sessionsCreate = "sessions.create"
    static let channelSend = "send"
}

// MARK: - Protocol

/// The operator-side surface of the gateway: everything HermesService needs,
/// hidden behind a protocol so the UI and voice tools can run against a mock.
@MainActor
protocol OperatorAPI: AnyObject {
    var onStateChange: ((GatewayConnectionState) -> Void)? { get set }
    var onAgentEvent: ((OperatorAgentEvent) -> Void)? { get set }

    func connect()
    func disconnect()
    /// Connects if needed and waits for the handshake to finish.
    func ensureConnected() async throws
    /// Sends a chat message; returns the run id identifying the streamed reply.
    func chatSend(sessionKey: String, text: String) async throws -> String
    func sessionsList() async throws -> [AgentSessionInfo]
    /// Creates a session and starts it on the task prompt; returns the session key.
    func spawnTask(_ spec: TaskSpec) async throws -> String
    func channelSend(channel: String, to: String, text: String) async throws
}

// MARK: - Gateway implementation

@MainActor
final class GatewayOperatorAPI: OperatorAPI {
    var onStateChange: ((GatewayConnectionState) -> Void)?
    var onAgentEvent: ((OperatorAgentEvent) -> Void)?

    private let identity: DeviceIdentity
    private let configProvider: () -> GatewayConfig
    private var client: GatewayClient?
    private var stateObservation: Task<Void, Never>?

    init(identity: DeviceIdentity, configProvider: @escaping () -> GatewayConfig) {
        self.identity = identity
        self.configProvider = configProvider
    }

    func connect() {
        disconnect()
        let client = GatewayClient(config: configProvider(), identity: identity, options: .operator)
        client.autoReconnect = true
        client.setDeviceToken(KeychainStore.get("gateway_device_token"))
        client.onDeviceToken = { KeychainStore.set($0, for: "gateway_device_token") }
        client.onEvent = { [weak self] event, payload in
            self?.handleEvent(event, payload: payload)
        }
        self.client = client
        stateObservation?.cancel()
        stateObservation = Task { @MainActor [weak self] in
            guard let self, let client = self.client else { return }
            for await state in client.$state.values {
                self.onStateChange?(state)
            }
        }
        client.connect()
    }

    func disconnect() {
        stateObservation?.cancel(); stateObservation = nil
        client?.disconnect()
        client = nil
        onStateChange?(.disconnected)
    }

    func ensureConnected() async throws {
        if client == nil { connect() }
        guard let client else { throw GatewayError(code: "DISCONNECTED", message: "No gateway client") }
        if client.state != .connected {
            if client.state == .disconnected { client.connect() }
            try await client.waitUntilConnected()
        }
    }

    func chatSend(sessionKey: String, text: String) async throws -> String {
        let runID = UUID().uuidString
        _ = try await requireClient().request(method: OperatorMethod.chatSend, params: [
            "sessionKey": sessionKey,
            "message": text,
            "deliver": false,
            "idempotencyKey": runID
        ])
        return runID
    }

    func sessionsList() async throws -> [AgentSessionInfo] {
        let payload = try await requireClient().request(method: OperatorMethod.sessionsList, params: [
            "limit": 50,
            "includeLastMessage": true,
            "includeDerivedTitles": true
        ])
        let entries = (payload["sessions"] ?? payload["items"] ?? payload["entries"]) as? [[String: Any]] ?? []
        return entries.compactMap { parseSession($0) }
    }

    func spawnTask(_ spec: TaskSpec) async throws -> String {
        var prompt = spec.prompt
        if let repo = spec.repo, !repo.isEmpty { prompt = "Repository: \(repo)\n\n" + prompt }
        var params: [String: Any] = ["message": prompt]
        if let label = spec.label, !label.isEmpty { params["label"] = label }
        let payload = try await requireClient().request(method: OperatorMethod.sessionsCreate, params: params)
        guard let key = payload["key"] as? String else {
            throw GatewayError(code: "BAD_RESPONSE", message: "sessions.create returned no key")
        }
        return key
    }

    func channelSend(channel: String, to: String, text: String) async throws {
        _ = try await requireClient().request(method: OperatorMethod.channelSend, params: [
            "channel": channel,
            "to": to,
            "message": text,
            "idempotencyKey": UUID().uuidString
        ])
    }

    // MARK: Event mapping

    private func handleEvent(_ event: String, payload: [String: Any]) {
        switch event {
        case "chat":
            let sessionKey = payload["sessionKey"] as? String ?? ""
            let runID = payload["runId"] as? String
            switch payload["state"] as? String {
            case "delta":
                onAgentEvent?(.replyDelta(
                    sessionKey: sessionKey, runID: runID,
                    cumulative: Self.extractText(payload["message"]),
                    delta: payload["deltaText"] as? String))
            case "final":
                onAgentEvent?(.replyFinal(
                    sessionKey: sessionKey, runID: runID,
                    text: Self.extractText(payload["message"]) ?? ""))
            case "error", "aborted":
                onAgentEvent?(.replyFailed(
                    sessionKey: sessionKey, runID: runID,
                    message: payload["errorMessage"] as? String ?? "Agent run failed"))
            default:
                break
            }
        case "sessions.changed", "session.message", "session.operation":
            onAgentEvent?(.sessionsChanged)
        default:
            break
        }
    }

    // MARK: Parsing

    private func requireClient() throws -> GatewayClient {
        guard let client else { throw GatewayError(code: "DISCONNECTED", message: "Not connected to gateway") }
        return client
    }

    private func parseSession(_ entry: [String: Any]) -> AgentSessionInfo? {
        guard let key = (entry["key"] ?? entry["sessionKey"] ?? entry["id"]) as? String else { return nil }
        let label = (entry["label"] ?? entry["title"] ?? entry["derivedTitle"]) as? String
        let updatedMs = (entry["updatedAt"] as? Double) ?? (entry["updatedAt"] as? Int).map(Double.init)
        return AgentSessionInfo(
            key: key,
            label: label?.isEmpty == false ? label! : key.components(separatedBy: ":").last ?? key,
            status: entry["status"] as? String ?? "",
            updatedAt: updatedMs.map { Date(timeIntervalSince1970: $0 / 1000) },
            lastMessage: Self.extractText(entry["lastMessage"])
        )
    }

    /// Chat message payloads vary: a plain string, `{text}`, or `{content:[{text}]}`.
    static func extractText(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        guard let dict = value as? [String: Any] else { return nil }
        if let string = dict["text"] as? String { return string }
        if let content = dict["content"] as? String { return content }
        if let parts = dict["content"] as? [[String: Any]] {
            let texts = parts.compactMap { $0["text"] as? String }
            if !texts.isEmpty { return texts.joined(separator: "\n") }
        }
        return nil
    }
}
