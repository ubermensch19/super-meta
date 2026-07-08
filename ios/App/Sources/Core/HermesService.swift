import Foundation
import SwiftUI
import AgentGateway

/// Operator-side link to the OpenClaw/Hermes agent: chat with streamed replies,
/// session status, task spawning, and outbound channel messages. Shares endpoint
/// config and device identity with the node-role `GatewayService` but runs its
/// own connection, so agent control and camera duty fail independently.
@MainActor
final class HermesService: ObservableObject {
    @Published private(set) var state: GatewayConnectionState = .disconnected
    @Published private(set) var messages: [HermesChatMessage] = []
    @Published private(set) var sessions: [AgentSessionInfo] = []
    /// In-flight reply text for the focused session, streamed as it arrives.
    @Published private(set) var streamingReply = ""
    @Published var focusedSessionKey = "main"

    /// Fires with hermes' full reply whenever a run finishes, even if the
    /// original `ask` already timed out — the voice layer uses this to announce
    /// late answers.
    var onReplyFinal: ((String) -> Void)?

    private let api: OperatorAPI
    private let gateway: GatewayService
    private struct ReplyBox: @unchecked Sendable { let text: String }
    private var pendingReplies: [String: CheckedContinuation<ReplyBox, Error>] = [:]

    var isConfigured: Bool { !gateway.token.isEmpty || UserDefaults.standard.bool(forKey: "hermes_use_mock") }

    init(gateway: GatewayService, api: OperatorAPI? = nil) {
        self.gateway = gateway
        if let api {
            self.api = api
        } else if UserDefaults.standard.bool(forKey: "hermes_use_mock") {
            self.api = MockOperatorAPI()
        } else {
            self.api = GatewayOperatorAPI(identity: gateway.identity) {
                GatewayConfig(host: gateway.host, port: gateway.port, useTLS: gateway.useTLS, token: gateway.token)
            }
        }
        self.api.onStateChange = { [weak self] in self?.state = $0 }
        self.api.onAgentEvent = { [weak self] in self?.handleAgentEvent($0) }
    }

    func connect() {
        guard state == .disconnected || state == .waitingForPairing else { return }
        api.connect()
    }

    func disconnect() {
        api.disconnect()
        failPendingReplies(GatewayError(code: "DISCONNECTED", message: "Gateway connection closed"))
    }

    // MARK: Actions

    /// Sends a message to hermes and awaits the full reply (streamed into
    /// `streamingReply` along the way). On timeout the run keeps going; the reply
    /// still lands in the transcript and `onReplyFinal` when it arrives.
    @discardableResult
    func ask(_ text: String, sessionKey: String? = nil, timeout: TimeInterval = 120) async throws -> String {
        try await api.ensureConnected()
        let key = sessionKey ?? focusedSessionKey
        messages.append(HermesChatMessage(role: .user, text: text))
        streamingReply = ""
        let runID = try await api.chatSend(sessionKey: key, text: text)
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

    // MARK: Events

    private func handleAgentEvent(_ event: OperatorAgentEvent) {
        switch event {
        case let .replyDelta(sessionKey, _, cumulative, delta):
            guard sessionKeysMatch(sessionKey, focusedSessionKey) else { return }
            if let cumulative {
                streamingReply = cumulative
            } else if let delta {
                streamingReply += delta
            }
        case let .replyFinal(sessionKey, runID, text):
            let reply = text.isEmpty ? streamingReply : text
            if sessionKeysMatch(sessionKey, focusedSessionKey) {
                streamingReply = ""
                messages.append(HermesChatMessage(role: .hermes, text: reply))
            }
            if let runID, let continuation = pendingReplies.removeValue(forKey: runID) {
                continuation.resume(returning: ReplyBox(text: reply))
            }
            onReplyFinal?(reply)
        case let .replyFailed(sessionKey, runID, message):
            if sessionKeysMatch(sessionKey, focusedSessionKey) {
                streamingReply = ""
                messages.append(HermesChatMessage(role: .system, text: "Run failed: \(message)"))
            }
            if let runID, let continuation = pendingReplies.removeValue(forKey: runID) {
                continuation.resume(throwing: GatewayError(code: "RUN_FAILED", message: message))
            }
        case .sessionsChanged:
            Task { @MainActor [weak self] in await self?.refreshSessions() }
        }
    }

    private func failPendingReplies(_ error: GatewayError) {
        let waiting = pendingReplies
        pendingReplies.removeAll()
        for continuation in waiting.values { continuation.resume(throwing: error) }
    }

    private func shortKey(_ key: String) -> String {
        key.components(separatedBy: ":").last ?? key
    }
}
