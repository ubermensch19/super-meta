import Foundation
import SwiftUI
import AgentGateway
import GlassesKit

/// App-level glue for the OpenClaw/Hermes gateway: owns the client, persists the
/// device identity + endpoint config, and implements the node command surface
/// (camera.snap, device.status, …) backed by the glasses.
@MainActor
final class GatewayService: ObservableObject, NodeCommandHandler {
    @Published var host: String { didSet { defaults.set(host, forKey: "gateway_host") } }
    @Published var port: Int { didSet { defaults.set(port, forKey: "gateway_port") } }
    @Published var useTLS: Bool { didSet { defaults.set(useTLS, forKey: "gateway_tls") } }

    @Published private(set) var state: GatewayConnectionState = .disconnected

    let nodeID: String

    /// Shared with the operator-role connection (HermesService) so one pairing
    /// approval covers the device.
    let identity: DeviceIdentity

    private let defaults = UserDefaults.standard
    private let glasses: GlassesService
    private var client: GatewayClient?
    private var stateObservation: Task<Void, Never>?

    init(glasses: GlassesService) {
        self.glasses = glasses
        self.host = defaults.string(forKey: "gateway_host") ?? "127.0.0.1"
        let savedPort = defaults.integer(forKey: "gateway_port")
        self.port = savedPort == 0 ? 18789 : savedPort
        self.useTLS = defaults.bool(forKey: "gateway_tls")

        // Stable device identity, persisted in the Keychain.
        let raw = KeychainStore.get("gateway_device_key").flatMap { Data(base64Encoded: $0) }
        let id = DeviceIdentity(rawPrivateKey: raw)
        if raw == nil { KeychainStore.set(id.rawPrivateKey.base64EncodedString(), for: "gateway_device_key") }
        self.identity = id
        self.nodeID = id.nodeID
    }

    var token: String {
        get { KeychainStore.get("gateway_token") ?? "" }
        set { KeychainStore.set(newValue, for: "gateway_token"); objectWillChange.send() }
    }

    func connect() {
        let config = GatewayConfig(host: host, port: port, useTLS: useTLS, token: token)
        let client = GatewayClient(config: config, identity: identity, handler: self)
        client.autoReconnect = true
        self.client = client
        stateObservation?.cancel()
        // Mirror the client's published state.
        stateObservation = Task { @MainActor [weak self] in
            guard let self, let client = self.client else { return }
            for await newState in client.$state.values {
                self.state = newState
            }
        }
        client.connect()
    }

    func disconnect() {
        client?.disconnect()
        client = nil
        state = .disconnected
    }

    // MARK: NodeCommandHandler

    func handle(method: String, params: [String: Any]) async throws -> [String: Any] {
        switch method {
        case "camera.snap":
            let maxWidth = (params["maxWidth"] as? Double).map { CGFloat($0) } ?? 1600
            let quality = (params["quality"] as? Double).map { CGFloat($0) } ?? 0.8
            if !glasses.isStreaming { await glasses.startStreaming() }
            guard let jpeg = glasses.currentFrameJPEG(maxWidth: maxWidth, quality: quality) else {
                throw GatewayError(code: "NO_FRAME", message: "No camera frame available")
            }
            return ["format": "jpg", "base64": jpeg.base64EncodedString(), "bytes": jpeg.count]
        case "camera.list":
            return ["cameras": [["id": "rayban-main", "name": "Ray-Ban Meta", "facing": "front"]]]
        case "device.status":
            return [
                "available": glasses.isAvailable,
                "connected": glasses.hasActiveDevice,
                "streaming": glasses.isStreaming
            ]
        case "device.info":
            return ["device": "rayban-meta", "app": "Super Meta", "platform": "ios", "node": nodeID]
        default:
            throw GatewayError(code: "UNKNOWN_COMMAND", message: method)
        }
    }
}
