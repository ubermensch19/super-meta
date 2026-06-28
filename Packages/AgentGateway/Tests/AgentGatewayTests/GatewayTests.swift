import XCTest
import CryptoKit
@testable import AgentGateway

final class GatewayProtocolTests: XCTestCase {

    func testFrameRoundTripRequest() throws {
        let frame = GatewayFrame.request(id: "1", method: "connect", params: ["role": "node"])
        let data = try frame.encoded()
        guard case let .request(id, method, params)? = GatewayFrame.decode(data) else {
            return XCTFail("decode failed")
        }
        XCTAssertEqual(id, "1")
        XCTAssertEqual(method, "connect")
        XCTAssertEqual(params["role"] as? String, "node")
    }

    func testFrameRoundTripResponseWithError() throws {
        let frame = GatewayFrame.response(id: "9", ok: false, payload: nil, error: GatewayError(code: "NOT_PAIRED", message: "pair me"))
        let data = try frame.encoded()
        guard case let .response(id, ok, _, error)? = GatewayFrame.decode(data) else {
            return XCTFail("decode failed")
        }
        XCTAssertEqual(id, "9")
        XCTAssertFalse(ok)
        XCTAssertEqual(error?.code, "NOT_PAIRED")
    }

    func testEventDecode() {
        let data = #"{"type":"event","event":"connect.challenge","payload":{"nonce":"abc"}}"#.data(using: .utf8)!
        guard case let .event(event, payload)? = GatewayFrame.decode(data) else {
            return XCTFail("decode failed")
        }
        XCTAssertEqual(event, "connect.challenge")
        XCTAssertEqual(payload["nonce"] as? String, "abc")
    }

    func testDeviceIdentityStableAndSignable() throws {
        let raw = Curve25519.Signing.PrivateKey().rawRepresentation
        let id1 = DeviceIdentity(rawPrivateKey: raw)
        let id2 = DeviceIdentity(rawPrivateKey: raw)
        // Same private key → same device id (stable across restarts).
        XCTAssertEqual(id1.deviceID, id2.deviceID)
        XCTAssertTrue(id1.nodeID.hasPrefix("rayban-"))
        XCTAssertEqual(id1.deviceID.count, 64) // hex SHA256

        // Signature verifies against the public key.
        let message = "v3|test"
        let sigB64 = try id1.sign(message)
        let sig = Data(base64Encoded: sigB64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((sigB64.count + 3) / 4) * 4, withPad: "=", startingAt: 0))!
        XCTAssertTrue(id1.privateKey.publicKey.isValidSignature(sig, for: Data(message.utf8)))
    }

    func testAuthSignedStringFormat() {
        let s = GatewayAuth.signedString(
            deviceID: "dev", clientID: "metamod-ios", clientMode: "node", role: "node",
            scopes: ["operator.read", "operator.write"], signedAtMs: 1000, token: "t",
            nonce: "n", platform: "ios", deviceFamily: "rayban"
        )
        XCTAssertEqual(s, "v3|dev|metamod-ios|node|node|operator.read,operator.write|1000|t|n|ios|rayban")
    }

    func testConfigURL() {
        let c = GatewayConfig(host: "127.0.0.1", port: 18789, useTLS: false, token: "abc")
        XCTAssertEqual(c.url?.absoluteString, "ws://127.0.0.1:18789?token=abc")
    }
}
