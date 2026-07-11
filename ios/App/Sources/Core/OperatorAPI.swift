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

/// Hermes backend JSON-RPC method names, isolated here so protocol drift only
/// touches this file. Verified against `hermes serve` (Hermes Agent 0.18.x).
enum OperatorMethod {
    static let sessionCreate = "session.create"
    static let sessionList = "session.list"
    static let sessionResume = "session.resume"
    static let promptSubmit = "prompt.submit"
    static let sessionInterrupt = "session.interrupt"
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

// MARK: - Hermes JSON-RPC implementation

/// Drives a Hermes Agent backend (`hermes serve`) over its JSON-RPC WebSocket.
/// A "session key" from the app is either the sentinel for the active
/// conversation or a stored session id from `session.list`; both resolve to a
/// live gateway session handle used for `prompt.submit`.
@MainActor
final class HermesOperatorAPI: OperatorAPI {
    var onStateChange: ((GatewayConnectionState) -> Void)?
    var onAgentEvent: ((OperatorAgentEvent) -> Void)?

    /// Sentinel meaning "the current conversation" (as opposed to a stored id).
    static let activeSessionKey = "main"

    private let configProvider: () -> HermesConfig
    private var client: HermesRPCClient?
    private var stateObservation: Task<Void, Never>?

    /// The live gateway session handle used for `prompt.submit` this connection.
    private var activeGatewaySession: String?
    /// The stored session id currently mapped to `activeGatewaySession`, if it
    /// came from resuming a listed session rather than a fresh create.
    private var activeStoredID: String?

    init(configProvider: @escaping () -> HermesConfig) {
        self.configProvider = configProvider
    }

    func connect() {
        // Idempotent: a launch-time auto-connect and a scenePhase resync can race;
        // don't tear down a live/in-flight socket and orphan its requests.
        if let existing = client, existing.state == .connecting || existing.state == .connected { return }
        disconnect()
        activeGatewaySession = nil
        activeStoredID = nil
        let client = HermesRPCClient(config: configProvider())
        client.onEvent = { [weak self] type, sessionID, payload in
            self?.handleEvent(type: type, sessionID: sessionID, payload: payload)
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
        activeGatewaySession = nil
        activeStoredID = nil
        onStateChange?(.disconnected)
    }

    func ensureConnected() async throws {
        if client == nil { connect() }
        guard let client else { throw GatewayError(code: "DISCONNECTED", message: "No Hermes client") }
        if client.state != .connected {
            if client.state == .disconnected { client.connect() }
            try await client.waitUntilConnected()
        }
    }

    func chatSend(sessionKey: String, text: String) async throws -> String {
        let gatewaySession = try await resolveSession(for: sessionKey)
        // prompt.submit returns immediately ({status:"streaming"}); the reply
        // arrives as message.delta / message.complete events keyed by this id.
        _ = try await requireClient().request(method: OperatorMethod.promptSubmit, params: [
            "session_id": gatewaySession,
            "text": text
        ])
        return gatewaySession
    }

    func sessionsList() async throws -> [AgentSessionInfo] {
        let payload = try await requireClient().request(method: OperatorMethod.sessionList, params: ["limit": 50])
        let entries = payload["sessions"] as? [[String: Any]] ?? []
        return entries.compactMap { parseSession($0) }
    }

    func spawnTask(_ spec: TaskSpec) async throws -> String {
        var prompt = spec.prompt
        if let repo = spec.repo, !repo.isEmpty { prompt = "Repository: \(repo)\n\n" + prompt }
        // A task is its own fresh session so it doesn't disturb the chat thread.
        let created = try await requireClient().request(method: OperatorMethod.sessionCreate, params: [:])
        guard let gatewaySession = created["session_id"] as? String else {
            throw GatewayError(code: "BAD_RESPONSE", message: "session.create returned no session_id")
        }
        _ = try await requireClient().request(method: OperatorMethod.promptSubmit, params: [
            "session_id": gatewaySession,
            "text": prompt
        ])
        return gatewaySession
    }

    func channelSend(channel: String, to: String, text: String) async throws {
        // The agent owns the messaging tools; instruct it to deliver.
        let gatewaySession = try await resolveSession(for: Self.activeSessionKey)
        _ = try await requireClient().request(method: OperatorMethod.promptSubmit, params: [
            "session_id": gatewaySession,
            "text": "Send this message to \(to) on \(channel), then confirm: \(text)"
        ])
    }

    // MARK: Session resolution

    /// Maps an app session key to a live gateway session handle, creating or
    /// resuming as needed.
    private func resolveSession(for sessionKey: String) async throws -> String {
        let client = try requireClient()
        // A stored id (from session.list) → resume it into a live handle.
        if sessionKey != Self.activeSessionKey, isStoredID(sessionKey) {
            if sessionKey == activeStoredID, let live = activeGatewaySession { return live }
            let resumed = try await client.request(method: OperatorMethod.sessionResume, params: ["session_id": sessionKey])
            guard let live = resumed["session_id"] as? String else {
                throw GatewayError(code: "BAD_RESPONSE", message: "session.resume returned no session_id")
            }
            activeGatewaySession = live
            activeStoredID = sessionKey
            return live
        }
        // The active conversation: reuse or create.
        if let live = activeGatewaySession { return live }
        let created = try await client.request(method: OperatorMethod.sessionCreate, params: [:])
        guard let live = created["session_id"] as? String else {
            throw GatewayError(code: "BAD_RESPONSE", message: "session.create returned no session_id")
        }
        activeGatewaySession = live
        activeStoredID = nil
        return live
    }

    /// Stored ids look like `20260711_150511_5f28b5`; gateway handles are short
    /// hex like `00ee0081`.
    private func isStoredID(_ key: String) -> Bool {
        key.contains("_") && key.first == "2"
    }

    // MARK: Event mapping

    private func handleEvent(type: String, sessionID: String?, payload: [String: Any]) {
        let key = sessionID ?? ""
        switch type {
        case "message.delta":
            if let text = payload["text"] as? String {
                onAgentEvent?(.replyDelta(sessionKey: key, runID: key, cumulative: nil, delta: text))
            }
        case "message.complete":
            if (payload["status"] as? String) == "error" {
                onAgentEvent?(.replyFailed(sessionKey: key, runID: key,
                                           message: payload["text"] as? String ?? "Agent run failed"))
            } else {
                onAgentEvent?(.replyFinal(sessionKey: key, runID: key,
                                          text: payload["text"] as? String ?? ""))
            }
        case "session.title", "session.info":
            onAgentEvent?(.sessionsChanged)
        default:
            break
        }
    }

    // MARK: Parsing

    private func requireClient() throws -> HermesRPCClient {
        guard let client else { throw GatewayError(code: "DISCONNECTED", message: "Not connected to Hermes") }
        return client
    }

    private func parseSession(_ entry: [String: Any]) -> AgentSessionInfo? {
        guard let id = entry["id"] as? String else { return nil }
        let title = entry["title"] as? String ?? ""
        let preview = entry["preview"] as? String ?? ""
        let startedAt = (entry["started_at"] as? Double) ?? (entry["started_at"] as? Int).map(Double.init)
        let messageCount = (entry["message_count"] as? Int) ?? 0
        return AgentSessionInfo(
            key: id,
            label: !title.isEmpty ? title : (!preview.isEmpty ? String(preview.prefix(40)) : id),
            status: messageCount > 0 ? "\(messageCount) msgs" : "new",
            updatedAt: startedAt.map { Date(timeIntervalSince1970: $0) },
            lastMessage: preview.isEmpty ? nil : preview
        )
    }
}
