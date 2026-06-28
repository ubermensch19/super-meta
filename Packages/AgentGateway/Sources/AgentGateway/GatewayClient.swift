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

/// WebSocket client for the OpenClaw/Hermes gateway protocol. Connects as a `node`,
/// signs the challenge with the device identity, and dispatches `node.invoke` to a handler.
/// The same client works for OpenClaw and Hermes — only the endpoint differs.
@MainActor
public final class GatewayClient: ObservableObject {
    @Published public private(set) var state: GatewayConnectionState = .disconnected

    private var config: GatewayConfig
    private let identity: DeviceIdentity
    private weak var handler: NodeCommandHandler?
    private let nowMs: @Sendable () -> Int64

    private var task: URLSessionWebSocketTask?
    private var session: URLSession
    private var keepaliveTask: Task<Void, Never>?

    private let clientID = "metamod-ios"
    private let scopes = ["operator.read", "operator.write"]

    public init(
        config: GatewayConfig,
        identity: DeviceIdentity,
        handler: NodeCommandHandler?,
        session: URLSession = .shared,
        nowMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.config = config
        self.identity = identity
        self.handler = handler
        self.session = session
        self.nowMs = nowMs
    }

    public func update(config: GatewayConfig) { self.config = config }

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
        keepaliveTask?.cancel(); keepaliveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    // MARK: Receive

    private func receiveLoop() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case let .success(message):
                    self.handleMessage(message)
                    self.receiveLoop()
                case let .failure(error):
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
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
            }
        case let .response(_, ok, payload, error):
            if let error {
                state = error.code == "NOT_PAIRED" ? .waitingForPairing : .error(error.message)
            } else if ok, case .connecting = state {
                state = .connected
                startKeepalive()
                _ = payload
            }
        case let .request(id, method, params):
            dispatch(id: id, method: method, params: params)
        }
    }

    // MARK: Connect handshake

    private func sendConnect(nonce: String) {
        let signedAt = nowMs()
        let signedString = GatewayAuth.signedString(
            deviceID: identity.deviceID, clientID: clientID, clientMode: "node",
            role: "node", scopes: scopes, signedAtMs: signedAt,
            token: config.token, nonce: nonce, platform: "ios", deviceFamily: "rayban"
        )
        let signature = (try? identity.sign(signedString)) ?? ""
        let params: [String: Any] = [
            "minProtocol": 3, "maxProtocol": 4,
            "client": ["id": clientID, "mode": "node", "name": "Meta-Mod"],
            "role": "node",
            "scopes": scopes,
            "caps": ["camera"],
            "commands": ["camera.snap", "camera.list", "device.status", "device.info"],
            "auth": ["token": config.token],
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
        send(.request(id: UUID().uuidString, method: "connect", params: params))
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

    private func send(_ frame: GatewayFrame) {
        guard let data = try? frame.encoded(), let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { error in
            if let error { log.error("send failed: \(error.localizedDescription)") }
        }
    }
}
