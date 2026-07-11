import Foundation
import SwiftUI
import AgentGateway

/// Link to a Hermes Agent backend (`hermes serve`): chat with streamed replies,
/// session status, task spawning, and outbound channel messages over the
/// backend's JSON-RPC WebSocket. Owns its own endpoint config (host/port/token).
@MainActor
final class HermesService: ObservableObject {
    @Published private(set) var state: GatewayConnectionState = .disconnected
    @Published private(set) var messages: [HermesChatMessage] = []
    @Published private(set) var sessions: [AgentSessionInfo] = []
    /// In-flight reply text for the focused session, streamed as it arrives.
    @Published private(set) var streamingReply = ""
    @Published var focusedSessionKey = HermesOperatorAPI.activeSessionKey

    // Endpoint config (non-secret in UserDefaults, token in Keychain).
    @Published var host: String { didSet { defaults.set(host, forKey: "hermes_host") } }
    @Published var port: Int { didSet { defaults.set(port, forKey: "hermes_port") } }
    @Published var useTLS: Bool { didSet { defaults.set(useTLS, forKey: "hermes_tls") } }

    /// Fires with the full reply of a run whose voice-budgeted ask already gave
    /// up — the voice layer announces these late answers.
    var onLateReply: ((String) -> Void)?

    private let defaults = UserDefaults.standard
    private let api: OperatorAPI
    private struct ReplyBox: @unchecked Sendable { let text: String }
    private var pendingReplies: [String: CheckedContinuation<ReplyBox, Error>] = [:]
    /// Runs that outlived their voice budget; their finals go to `onLateReply`.
    private var lateReplyRuns: Set<String> = []
    /// Live gateway session handle of the in-flight `ask`, used to match its
    /// streamed reply events (which are keyed by that handle, not the UI focus).
    private var activeRunSessionID: String?

    var token: String {
        get { KeychainStore.get("hermes_token") ?? "" }
        set { KeychainStore.set(newValue, for: "hermes_token"); objectWillChange.send() }
    }

    /// Optional launch-time endpoint override (`HERMES_ENDPOINT=ws://host:port?token=…`),
    /// handy for wiring the app to a local `hermes serve` without pairing UI.
    private static let envEndpoint = ProcessInfo.processInfo.environment["HERMES_ENDPOINT"]
        .flatMap { HermesPairingView.parseEndpoint($0) }

    var isConfigured: Bool {
        Self.envEndpoint != nil || !token.isEmpty || UserDefaults.standard.bool(forKey: "hermes_use_mock")
    }

    init(api: OperatorAPI? = nil) {
        let env = Self.envEndpoint
        self.host = env?.host ?? defaults.string(forKey: "hermes_host") ?? "127.0.0.1"
        let savedPort = defaults.integer(forKey: "hermes_port")
        self.port = env?.port ?? (savedPort == 0 ? 9119 : savedPort)
        self.useTLS = env?.tls ?? defaults.bool(forKey: "hermes_tls")

        if let api {
            self.api = api
        } else if UserDefaults.standard.bool(forKey: "hermes_use_mock") {
            self.api = MockOperatorAPI()
        } else {
            let defaults = self.defaults
            self.api = HermesOperatorAPI {
                if let env = HermesService.envEndpoint {
                    return HermesConfig(host: env.host, port: env.port, useTLS: env.tls, token: env.token ?? "")
                }
                let host = defaults.string(forKey: "hermes_host") ?? "127.0.0.1"
                let savedPort = defaults.integer(forKey: "hermes_port")
                return HermesConfig(
                    host: host,
                    port: savedPort == 0 ? 9119 : savedPort,
                    useTLS: defaults.bool(forKey: "hermes_tls"),
                    token: KeychainStore.get("hermes_token") ?? ""
                )
            }
        }
        self.api.onStateChange = { [weak self] in self?.state = $0 }
        self.api.onAgentEvent = { [weak self] in self?.handleAgentEvent($0) }

        // With an explicit launch endpoint, connect right away so the link is
        // live app-wide (not only once the Hermes screen appears).
        if Self.envEndpoint != nil {
            Task { @MainActor [weak self] in self?.connect() }
        }
    }

    /// Whether the user asked for a live link (drives foreground resync).
    private var wantsConnection = false

    func connect() {
        wantsConnection = true
        guard state != .connected, state != .connecting else { return }
        api.connect()
    }

    func disconnect() {
        wantsConnection = false
        api.disconnect()
        failPendingReplies(GatewayError(code: "DISCONNECTED", message: "Gateway connection closed"))
    }

    /// Backgrounding suspends the socket; reconnect and refresh when we return.
    func resyncOnForeground() {
        guard wantsConnection else { return }
        if state != .connected, state != .connecting { api.connect() }
        Task { @MainActor [weak self] in await self?.refreshSessions() }
    }

    // MARK: Actions

    /// Sends a message to hermes and awaits the full reply (streamed into
    /// `streamingReply` along the way). On timeout the run keeps going; the reply
    /// still lands in the transcript and `onReplyFinal` when it arrives.
    @discardableResult
    func ask(_ text: String, sessionKey: String? = nil, timeout: TimeInterval = 120) async throws -> String {
        let runID = try await startRun(text, sessionKey: sessionKey)
        return try await awaitReply(runID: runID, timeout: timeout)
    }

    /// Voice variant of `ask`: waits only `budget` seconds, then returns nil and
    /// routes the eventual reply to `onLateReply` so it can be spoken when ready.
    func askWithBudget(_ text: String, sessionKey: String? = nil, budget: TimeInterval = 12) async throws -> String? {
        let runID = try await startRun(text, sessionKey: sessionKey)
        do {
            return try await awaitReply(runID: runID, timeout: budget)
        } catch let error as GatewayError where error.code == "TIMEOUT" {
            lateReplyRuns.insert(runID)
            return nil
        }
    }

    private func startRun(_ text: String, sessionKey: String?) async throws -> String {
        try await api.ensureConnected()
        let key = sessionKey ?? focusedSessionKey
        messages.append(HermesChatMessage(role: .user, text: text))
        streamingReply = ""
        // chatSend returns the live gateway session handle; reply events are
        // keyed by it, so track it for streaming/transcript matching.
        let runID = try await api.chatSend(sessionKey: key, text: text)
        activeRunSessionID = runID
        return runID
    }

    private func awaitReply(runID: String, timeout: TimeInterval) async throws -> String {
        let box: ReplyBox = try await withCheckedThrowingContinuation { continuation in
            pendingReplies[runID] = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.pendingReplies.removeValue(forKey: runID)?
                    .resume(throwing: GatewayError(code: "TIMEOUT", message: "Hermes is still working on it"))
            }
        }
        return box.text
    }

    /// Dispatches a new agent task (e.g. a coding job); returns the session key.
    func spawnTask(prompt: String, repo: String? = nil, label: String? = nil) async throws -> String {
        try await api.ensureConnected()
        let key = try await api.spawnTask(TaskSpec(prompt: prompt, repo: repo, label: label))
        messages.append(HermesChatMessage(role: .system, text: "Task started in session \(shortKey(key))"))
        await refreshSessions()
        return key
    }

    /// Sends an outbound message through one of hermes' channels (telegram, whatsapp, …).
    func sendChannelMessage(channel: String, to: String, text: String) async throws {
        try await api.ensureConnected()
        try await api.channelSend(channel: channel, to: to, text: text)
        messages.append(HermesChatMessage(role: .system, text: "Sent via \(channel) to \(to)"))
    }

    func refreshSessions() async {
        guard let list = try? await api.sessionsList() else { return }
        sessions = list
    }

    // MARK: Voice tool calls

    /// Dispatches a realtime function call from the voice model. Always returns a
    /// JSON string — errors included — so the model can verbalize the outcome.
    func handleToolCall(name: String, argumentsJSON: String) async -> String {
        let args = (try? JSONSerialization.jsonObject(with: Data(argumentsJSON.utf8))) as? [String: Any] ?? [:]
        do {
            switch name {
            case "hermes_ask":
                guard let question = args["question"] as? String, !question.isEmpty else {
                    return Self.toolJSON(["error": "Missing question"])
                }
                if let reply = try await askWithBudget(question, sessionKey: args["session_id"] as? String) {
                    return Self.toolJSON(["reply": reply])
                }
                return Self.toolJSON([
                    "status": "working",
                    "note": "Hermes is still thinking. The answer will be announced when it's ready."
                ])
            case "hermes_spawn_task":
                guard let prompt = args["prompt"] as? String, !prompt.isEmpty else {
                    return Self.toolJSON(["error": "Missing prompt"])
                }
                let key = try await spawnTask(prompt: prompt, repo: args["repo"] as? String)
                return Self.toolJSON(["status": "started", "session": shortKey(key)])
            case "hermes_send_message":
                guard let recipient = args["recipient"] as? String, !recipient.isEmpty,
                      let message = args["message"] as? String, !message.isEmpty else {
                    return Self.toolJSON(["error": "Missing recipient or message"])
                }
                let channel = args["channel"] as? String ?? "telegram"
                try await sendChannelMessage(channel: channel, to: recipient, text: message)
                return Self.toolJSON(["status": "sent", "channel": channel, "recipient": recipient])
            case "hermes_sessions_status":
                try await api.ensureConnected()
                await refreshSessions()
                let summary = sessions.map { session -> [String: Any] in
                    var entry: [String: Any] = ["session": session.label, "status": session.status]
                    if let last = session.lastMessage { entry["lastMessage"] = String(last.prefix(200)) }
                    return entry
                }
                return Self.toolJSON(["sessions": summary])
            default:
                return Self.toolJSON(["error": "Unknown tool \(name)"])
            }
        } catch let error as GatewayError {
            return Self.toolJSON(["error": error.message])
        } catch {
            return Self.toolJSON(["error": error.localizedDescription])
        }
    }

    private static func toolJSON(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"error":"Failed to encode tool result"}"#
        }
        return string
    }

    // MARK: Events

    private func handleAgentEvent(_ event: OperatorAgentEvent) {
        switch event {
        case let .replyDelta(sessionKey, _, cumulative, delta):
            guard isActiveRun(sessionKey) else { return }
            if let cumulative {
                streamingReply = cumulative
            } else if let delta {
                streamingReply += delta
            }
        case let .replyFinal(sessionKey, runID, text):
            let reply = text.isEmpty ? streamingReply : text
            if isActiveRun(sessionKey) {
                streamingReply = ""
                messages.append(HermesChatMessage(role: .hermes, text: reply))
            }
            if let runID, let continuation = pendingReplies.removeValue(forKey: runID) {
                continuation.resume(returning: ReplyBox(text: reply))
            }
            if let runID, lateReplyRuns.remove(runID) != nil {
                onLateReply?(reply)
            }
        case let .replyFailed(sessionKey, runID, message):
            if isActiveRun(sessionKey) {
                streamingReply = ""
                messages.append(HermesChatMessage(role: .system, text: "Run failed: \(message)"))
            }
            if let runID, let continuation = pendingReplies.removeValue(forKey: runID) {
                continuation.resume(throwing: GatewayError(code: "RUN_FAILED", message: message))
            }
            if let runID { lateReplyRuns.remove(runID) }
        case .sessionsChanged:
            Task { @MainActor [weak self] in await self?.refreshSessions() }
        }
    }

    private func failPendingReplies(_ error: GatewayError) {
        let waiting = pendingReplies
        pendingReplies.removeAll()
        for continuation in waiting.values { continuation.resume(throwing: error) }
    }

    private func isActiveRun(_ sessionKey: String) -> Bool {
        guard let active = activeRunSessionID else { return false }
        return sessionKey == active
    }

    private func shortKey(_ key: String) -> String {
        key.components(separatedBy: ":").last ?? key
    }
}
