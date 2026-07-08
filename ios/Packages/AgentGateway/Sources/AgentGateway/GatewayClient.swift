import Foundation
import os.log

private let log = Logger(subsystem: "com.priyanshu.metamod", category: "AgentGateway")

public struct GatewayConfig: Sendable, Equatable {
    public var host: String
    public var port: Int
    public var useTLS: Bool
    public var token: String

    public init(host: String = "127.0.0.1", port: Int = 18789, useTLS: Bool = false, token: String = "") {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.token = token
    }

    public var url: URL? {
        var components = URLComponents()
        components.scheme = useTLS ? "wss" : "ws"
        components.host = host
        components.port = port
        if !token.isEmpty { components.queryItems = [URLQueryItem(name: "token", value: token)] }
        return components.url
    }
}

/// Role-specific parameters for the `connect` handshake. The gateway validates the
/// params schema strictly (additionalProperties: false), so operator connections must
/// not carry node-only fields like `caps`/`commands`.
public struct GatewayConnectOptions: Sendable, Equatable {
    public var mode: String
    public var role: String
    public var scopes: [String]
    public var caps: [String]
    public var commands: [String]
    public var clientID: String
    public var clientName: String
    /// Key used for the client display name ("name" for the legacy node frame,
    /// "displayName" per the v4 schema).
    public var clientNameKey: String
    public var minProtocol: Int
    public var maxProtocol: Int

    public init(
        mode: String, role: String, scopes: [String],
        caps: [String] = [], commands: [String] = [],
        clientID: String = "metamod-ios", clientName: String = "Super Meta",
        clientNameKey: String = "displayName",
        minProtocol: Int = 4, maxProtocol: Int = 4
    ) {
        self.mode = mode
        self.role = role
        self.scopes = scopes
        self.caps = caps
        self.commands = commands
        self.clientID = clientID
        self.clientName = clientName
        self.clientNameKey = clientNameKey
        self.minProtocol = minProtocol
        self.maxProtocol = maxProtocol
    }

    /// The glasses node: the agent invokes camera/device commands on us.
    public static let node = GatewayConnectOptions(
        mode: "node", role: "node",
        scopes: ["operator.read", "operator.write"],
        caps: ["camera"],
        commands: ["camera.snap", "camera.list", "device.status", "device.info"],
        clientNameKey: "name",
        minProtocol: 3, maxProtocol: 4
    )

    /// Control-plane client: we drive the agent (chat.send, sessions.*, send).
    /// Operators must speak protocol v4.
    public static let `operator` = GatewayConnectOptions(
        mode: "operator", role: "operator",
        scopes: ["operator.read", "operator.write"]
    )
}

public enum GatewayConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case waitingForPairing
    case error(String)
}

/// Handles `node.invoke` commands forwarded by the gateway (camera.snap, device.status, …).
/// Main-actor isolated so non-Sendable JSON params stay on the actor.
@MainActor
public protocol NodeCommandHandler: AnyObject {
    /// Returns the result payload, or throws `GatewayError`.
    func handle(method: String, params: [String: Any]) async throws -> [String: Any]
}

/// WebSocket client for the OpenClaw/Hermes gateway protocol. Connects as a `node`
/// (the agent drives us) or an `operator` (we drive the agent) depending on the
/// connect options, signing the challenge with the device identity either way.
/// The same client works for OpenClaw and Hermes — only the endpoint differs.
@MainActor
public final class GatewayClient: ObservableObject {
    @Published public private(set) var state: GatewayConnectionState = .disconnected

    /// Fires for every gateway event except the internal `connect.challenge`.
    public var onEvent: ((_ event: String, _ payload: [String: Any]) -> Void)?
    /// Fires when the hello-ok handshake issues a device token worth persisting.
    public var onDeviceToken: ((String) -> Void)?
    /// Reconnect automatically with exponential backoff after a dropped socket.
    public var autoReconnect = false

    public private(set) var deviceToken: String?

    private var config: GatewayConfig
    private let identity: DeviceIdentity
    private let options: GatewayConnectOptions
    private weak var handler: NodeCommandHandler?
    private let nowMs: @Sendable () -> Int64

    private var task: URLSessionWebSocketTask?
    private var session: URLSession
    private var keepaliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0

    /// Payloads are produced and consumed on the main actor; the box only carries
    /// the non-Sendable JSON dictionary across the continuation hop.
    private struct PayloadBox: @unchecked Sendable { let values: [String: Any] }
    private var pending: [String: CheckedContinuation<PayloadBox, Error>] = [:]
    private var connectRequestID: String?

    public init(
        config: GatewayConfig,
        identity: DeviceIdentity,
        handler: NodeCommandHandler? = nil,
        options: GatewayConnectOptions = .node,
        session: URLSession = .shared,
        nowMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.config = config
        self.identity = identity
        self.handler = handler
        self.options = options
        self.session = session
        self.nowMs = nowMs
    }

    public func update(config: GatewayConfig) { self.config = config }

    /// Seeds a device token persisted from a previous session's hello-ok.
    public func setDeviceToken(_ token: String?) { deviceToken = token }

    public func connect() {
        guard let url = config.url else { state = .error("Invalid gateway URL"); return }
        disconnect()
        state = .connecting
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop()
    }

    public func disconnect() {
        reconnectTask?.cancel(); reconnectTask = nil
        keepaliveTask?.cancel(); keepaliveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connectRequestID = nil
        failPending(GatewayError(code: "DISCONNECTED", message: "Gateway connection closed"))
        state = .disconnected
    }

    // MARK: Requests

    /// Sends a request frame and awaits the correlated response payload.
    public func request(method: String, params: [String: Any] = [:], timeout: TimeInterval = 30) async throws -> [String: Any] {
        guard task != nil else { throw GatewayError(code: "DISCONNECTED", message: "Not connected to gateway") }
        let id = UUID().uuidString
        let box: PayloadBox = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            send(.request(id: id, method: method, params: params))
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.pending.removeValue(forKey: id)?
                    .resume(throwing: GatewayError(code: "TIMEOUT", message: "\(method) timed out"))
            }
        }
        return box.values
    }

    /// Waits until the handshake completes, throwing on pairing/error states.
    public func waitUntilConnected(timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch state {
            case .connected: return
            case .waitingForPairing: throw GatewayError(code: "NOT_PAIRED", message: "Device awaiting pairing approval")
            case let .error(message): throw GatewayError(code: "CONNECT_FAILED", message: message)
            case .disconnected, .connecting:
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        throw GatewayError(code: "TIMEOUT", message: "Gateway connect timed out")
    }

    private func failPending(_ error: GatewayError) {
        let waiting = pending
        pending.removeAll()
        for continuation in waiting.values { continuation.resume(throwing: error) }
    }

    // MARK: Receive

    private func receiveLoop() {
        guard let current = task else { return }
        current.receive { [weak self] result in
            Task { @MainActor [weak self] in
                // Ignore callbacks from a socket that was already replaced or torn down.
                guard let self, self.task === current else { return }
                switch result {
                case let .success(message):
                    self.handleMessage(message)
                    self.receiveLoop()
                case let .failure(error):
                    self.handleSocketFailure(error, socket: current)
                }
            }
        }
    }

    private func handleSocketFailure(_ error: Error, socket: URLSessionWebSocketTask) {
        let pairingRejected = socket.closeCode == .policyViolation // 1008 "pairing required"
        self.task = nil
        keepaliveTask?.cancel(); keepaliveTask = nil
        connectRequestID = nil
        failPending(GatewayError(code: "DISCONNECTED", message: "Gateway connection lost"))
        if pairingRejected {
            state = .waitingForPairing
            return
        }
        state = .error(error.localizedDescription)
        if autoReconnect { scheduleReconnect() }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt)))
        reconnectAttempt += 1
        log.info("gateway reconnect in \(delay, format: .fixed(precision: 0))s (attempt \(self.reconnectAttempt))")
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled, self.task == nil else { return }
            self.connect()
        }
    }

    func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case let .data(d): data = d
        case let .string(s): data = Data(s.utf8)
        @unknown default: return
        }
        guard let frame = GatewayFrame.decode(data) else { return }
        switch frame {
        case let .event(event, payload):
            if event == "connect.challenge", let nonce = payload["nonce"] as? String {
                sendConnect(nonce: nonce)
            } else {
                onEvent?(event, payload)
            }
        case let .response(id, ok, payload, error):
            if let continuation = pending.removeValue(forKey: id) {
                if ok {
                    continuation.resume(returning: PayloadBox(values: payload ?? [:]))
                } else {
                    continuation.resume(throwing: error ?? GatewayError(code: "ERROR", message: "Request failed"))
                }
            } else if id == connectRequestID {
                connectRequestID = nil
                if let error {
                    state = error.code == "NOT_PAIRED" ? .waitingForPairing : .error(error.message)
                } else if ok {
                    state = .connected
                    reconnectAttempt = 0
                    if let auth = payload?["auth"] as? [String: Any],
                       let issued = auth["deviceToken"] as? String, !issued.isEmpty {
                        deviceToken = issued
                        onDeviceToken?(issued)
                    }
                    startKeepalive()
                }
            }
            // Anything else (e.g. ping acks) is intentionally dropped.
        case let .request(id, method, params):
            dispatch(id: id, method: method, params: params)
        }
    }

    // MARK: Connect handshake

    func connectParams(nonce: String, signedAt: Int64) -> [String: Any] {
        let signedString = GatewayAuth.signedString(
            deviceID: identity.deviceID, clientID: options.clientID, clientMode: options.mode,
            role: options.role, scopes: options.scopes, signedAtMs: signedAt,
            token: config.token, nonce: nonce, platform: "ios", deviceFamily: "rayban"
        )
        let signature = (try? identity.sign(signedString)) ?? ""
        var auth: [String: Any] = ["token": config.token]
        if let deviceToken { auth["deviceToken"] = deviceToken }
        var params: [String: Any] = [
            "minProtocol": options.minProtocol, "maxProtocol": options.maxProtocol,
            "client": ["id": options.clientID, "mode": options.mode, options.clientNameKey: options.clientName],
            "role": options.role,
            "scopes": options.scopes,
            "auth": auth,
            "device": [
                "id": identity.deviceID,
                "publicKey": identity.publicKeyB64URL,
                "nonce": nonce,
                "signedAt": signedAt,
                "signature": signature,
                "platform": "ios",
                "deviceFamily": "rayban"
            ]
        ]
        if !options.caps.isEmpty { params["caps"] = options.caps }
        if !options.commands.isEmpty { params["commands"] = options.commands }
        return params
    }

    private func sendConnect(nonce: String) {
        let id = UUID().uuidString
        connectRequestID = id
        send(.request(id: id, method: "connect", params: connectParams(nonce: nonce, signedAt: nowMs())))
    }

    // MARK: node.invoke dispatch

    private func dispatch(id: String, method: String, params: [String: Any]) {
        guard method == "node.invoke" else {
            send(.response(id: id, ok: false, payload: nil, error: GatewayError(code: "UNKNOWN_METHOD", message: method)))
            return
        }
        let command = params["command"] as? String ?? ""
        let args = params["params"] as? [String: Any] ?? [:]
        Task { @MainActor [weak self] in
            guard let self, let handler = self.handler else {
                self?.send(.response(id: id, ok: false, payload: nil, error: GatewayError(code: "NO_HANDLER", message: "No node handler")))
                return
            }
            do {
                let payload = try await handler.handle(method: command, params: args)
                self.send(.response(id: id, ok: true, payload: payload, error: nil))
            } catch let error as GatewayError {
                self.send(.response(id: id, ok: false, payload: nil, error: error))
            } catch {
                self.send(.response(id: id, ok: false, payload: nil, error: GatewayError(code: "ERROR", message: error.localizedDescription)))
            }
        }
    }

    // MARK: Keepalive

    private func startKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
                guard let self, self.state == .connected else { return }
                self.send(.request(id: UUID().uuidString, method: "ping", params: [:]))
            }
        }
    }

    // MARK: Send

    /// Test seam: observes every outgoing frame (called on the main actor).
    var onOutgoingFrame: ((GatewayFrame) -> Void)?

    /// Test seam: installs an inert socket so request/response correlation can be
    /// exercised without the network. The task is never resumed, so nothing is sent.
    func openForTesting() {
        task = session.webSocketTask(with: URL(string: "ws://127.0.0.1:1")!)
    }

    private func send(_ frame: GatewayFrame) {
        onOutgoingFrame?(frame)
        guard let data = try? frame.encoded(), let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { error in
            if let error { log.error("send failed: \(error.localizedDescription)") }
        }
    }
}
