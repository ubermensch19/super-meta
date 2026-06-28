import Foundation
import CryptoKit

// MARK: - Wire frames

/// The three frame types in the OpenClaw/Hermes gateway protocol.
public enum GatewayFrame {
    case request(id: String, method: String, params: [String: Any])
    case response(id: String, ok: Bool, payload: [String: Any]?, error: GatewayError?)
    case event(event: String, payload: [String: Any])

    public func encoded() throws -> Data {
        var object: [String: Any]
        switch self {
        case let .request(id, method, params):
            object = ["type": "req", "id": id, "method": method, "params": params]
        case let .response(id, ok, payload, error):
            object = ["type": "res", "id": id, "ok": ok]
            if let payload { object["payload"] = payload }
            if let error { object["error"] = ["code": error.code, "message": error.message] }
        case let .event(event, payload):
            object = ["type": "event", "event": event, "payload": payload]
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    public static func decode(_ data: Data) -> GatewayFrame? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return nil }
        switch type {
        case "req":
            guard let id = json["id"] as? String, let method = json["method"] as? String else { return nil }
            return .request(id: id, method: method, params: json["params"] as? [String: Any] ?? [:])
        case "res":
            guard let id = json["id"] as? String else { return nil }
            let err = (json["error"] as? [String: Any]).map {
                GatewayError(code: $0["code"] as? String ?? "", message: $0["message"] as? String ?? "")
            }
            return .response(id: id, ok: json["ok"] as? Bool ?? false, payload: json["payload"] as? [String: Any], error: err)
        case "event":
            guard let event = json["event"] as? String else { return nil }
            return .event(event: event, payload: json["payload"] as? [String: Any] ?? [:])
        default:
            return nil
        }
    }
}

public struct GatewayError: Error, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

// MARK: - Device identity (Ed25519)

/// A stable Ed25519 device identity used to authenticate with the gateway.
public struct DeviceIdentity {
    public let privateKey: Curve25519.Signing.PrivateKey

    public init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    /// Restores an identity from raw 32-byte private key data, or creates a new one.
    public init(rawPrivateKey: Data?) {
        if let raw = rawPrivateKey, let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) {
            self.privateKey = key
        } else {
            self.privateKey = Curve25519.Signing.PrivateKey()
        }
    }

    public var rawPrivateKey: Data { privateKey.rawRepresentation }

    /// Raw 32-byte public key.
    public var publicKeyRaw: Data { privateKey.publicKey.rawRepresentation }

    /// base64url-encoded public key (no padding).
    public var publicKeyB64URL: String { Self.base64url(publicKeyRaw) }

    /// Device id = hex(SHA256(publicKey)).
    public var deviceID: String {
        SHA256.hash(data: publicKeyRaw).map { String(format: "%02x", $0) }.joined()
    }

    /// A friendly node id derived from the device id.
    public var nodeID: String { "rayban-" + String(deviceID.prefix(8)) }

    public func sign(_ string: String) throws -> String {
        let signature = try privateKey.signature(for: Data(string.utf8))
        return Self.base64url(signature)
    }

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Auth payload

/// Builds the v3-format signed string the gateway expects in the connect request.
public enum GatewayAuth {
    public static func signedString(
        deviceID: String,
        clientID: String,
        clientMode: String,
        role: String,
        scopes: [String],
        signedAtMs: Int64,
        token: String,
        nonce: String,
        platform: String,
        deviceFamily: String
    ) -> String {
        [
            "v3", deviceID, clientID, clientMode, role,
            scopes.joined(separator: ","),
            String(signedAtMs), token, nonce, platform, deviceFamily
        ].joined(separator: "|")
    }
}
