import Foundation
import os.log
import AgentGateway

private let log = Logger(subsystem: "com.priyanshu.metamod", category: "HermesRPC")

/// Endpoint for a Hermes Agent backend (`hermes serve`), which speaks
/// newline-delimited JSON-RPC 2.0 over a WebSocket at `/api/ws`. On a loopback
/// bind the session token authenticates via the `?token=` query param.
struct HermesConfig: Sendable, Equatable {
    var host: String
    var port: Int
    var useTLS: Bool
    var token: String

    init(host: String = "127.0.0.1", port: Int = 9119, useTLS: Bool = false, token: String = "") {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.token = token
    }

    var webSocketURL: URL? {
        var components = URLComponents()
        components.scheme = useTLS ? "wss" : "ws"
        components.host = host
        components.port = port
        components.path = "/api/ws"
        if !token.isEmpty { components.queryItems = [URLQueryItem(name: "token", value: token)] }
        return components.url
    }
}

/// A JSON-RPC 2.0 client for the Hermes backend WebSocket. Correlates responses
/// to requests by id and forwards server events (`message.delta`, `session.info`,
/// …) to a callback. Main-actor isolated so non-Sendable JSON payloads stay put.
@MainActor
final class HermesRPCClient: ObservableObject {
    @Published private(set) var state: GatewayConnectionState = .disconnected

    /// Fires for every JSON-RPC event notification (method == "event").
    var onEvent: ((_ type: String, _ sessionID: String?, _ payload: [String: Any]) -> Void)?

    private var config: HermesConfig
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    private struct PayloadBox: @unchecked Sendable { let values: [String: Any] }
    private var pending: [Int: CheckedContinuation<PayloadBox, Error>] = [:]
    private var nextID = 1

    init(config: HermesConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func update(config: HermesConfig) { self.config = config }

    func connect() {
        guard let url = config.webSocketURL else { state = .error("Invalid Hermes URL"); return }
        disconnect()
        state = .connecting
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop(on: task)
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        failPending(GatewayError(code: "DISCONNECTED", message: "Hermes connection closed"))
        if state != .disconnected { state = .disconnected }
    }

    /// Waits until `gateway.ready` has arrived (or the socket errors/closes).
    func waitUntilConnected(timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch state {
            case .connected: return
            case let .error(message): throw GatewayError(code: "CONNECT_FAILED", message: message)
            case .waitingForPairing: throw GatewayError(code: "UNAUTHORIZED", message: "Hermes rejected the token")
            case .disconnected, .connecting:
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        throw GatewayError(code: "TIMEOUT", message: "Hermes connect timed out")
    }

    // MARK: Requests

    func request(method: String, params: [String: Any] = [:], timeout: TimeInterval = 60) async throws -> [String: Any] {
        guard task != nil else { throw GatewayError(code: "DISCONNECTED", message: "Not connected to Hermes") }
        let id = nextID
        nextID += 1
        let box: PayloadBox = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            send(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.pending.removeValue(forKey: id)?
                    .resume(throwing: GatewayError(code: "TIMEOUT", message: "\(method) timed out"))
            }
        }
        return box.values
    }

    private func failPending(_ error: GatewayError) {
        let waiting = pending
        pending.removeAll()
        for continuation in waiting.values { continuation.resume(throwing: error) }
    }

    // MARK: Receive

    private func receiveLoop(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.task === socket else { return }
                switch result {
                case let .success(message):
                    self.handle(message)
                    self.receiveLoop(on: socket)
                case let .failure(error):
                    self.handleFailure(error, socket: socket)
                }
            }
        }
    }

    private func handleFailure(_ error: Error, socket: URLSessionWebSocketTask) {
        // 4401 = token rejected; anything else is a generic drop.
        let unauthorized = socket.closeCode == URLSessionWebSocketTask.CloseCode(rawValue: 4401)
        task = nil
        failPending(GatewayError(code: "DISCONNECTED", message: "Hermes connection lost"))
        state = unauthorized ? .error("Hermes rejected the token — check it and try again.") : .error(error.localizedDescription)
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case let .string(s): text = s
        case let .data(d): text = String(decoding: d, as: UTF8.self)
        @unknown default: return
        }
        // Newline-delimited: a frame may carry more than one JSON object.
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            route(json)
        }
    }

    private func route(_ json: [String: Any]) {
        // Response: carries an id we're waiting on.
        if let id = json["id"] as? Int, let continuation = pending.removeValue(forKey: id) {
            if let error = json["error"] as? [String: Any] {
                let code = (error["code"] as? Int).map(String.init) ?? "ERROR"
                continuation.resume(throwing: GatewayError(code: code, message: error["message"] as? String ?? "Request failed"))
            } else {
                continuation.resume(returning: PayloadBox(values: json["result"] as? [String: Any] ?? [:]))
            }
            return
        }
        // Event notification.
        if (json["method"] as? String) == "event", let params = json["params"] as? [String: Any] {
            let type = params["type"] as? String ?? ""
            if type == "gateway.ready" {
                state = .connected
                return
            }
            onEvent?(type, params["session_id"] as? String, params["payload"] as? [String: Any] ?? [:])
        }
    }

    // MARK: Send

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { error in
            if let error { log.error("hermes send failed: \(error.localizedDescription)") }
        }
    }
}
