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

    func testAuthSignedStringOperator() {
        let s = GatewayAuth.signedString(
            deviceID: "dev", clientID: "metamod-ios", clientMode: "operator", role: "operator",
            scopes: ["operator.read", "operator.write"], signedAtMs: 1000, token: "t",
            nonce: "n", platform: "ios", deviceFamily: "rayban"
        )
        XCTAssertEqual(s, "v3|dev|metamod-ios|operator|operator|operator.read,operator.write|1000|t|n|ios|rayban")
    }
}

@MainActor
final class GatewayClientTests: XCTestCase {

    private func makeClient(options: GatewayConnectOptions) -> GatewayClient {
        GatewayClient(
            config: GatewayConfig(token: "tok"),
            identity: DeviceIdentity(rawPrivateKey: nil),
            options: options,
            nowMs: { 1234 }
        )
    }

    func testNodeConnectParamsUnchanged() {
        let client = makeClient(options: .node)
        let params = client.connectParams(nonce: "n", signedAt: 1234)
        XCTAssertEqual(params["role"] as? String, "node")
        XCTAssertEqual(params["minProtocol"] as? Int, 3)
        XCTAssertEqual(params["maxProtocol"] as? Int, 4)
        XCTAssertEqual(params["caps"] as? [String], ["camera"])
        XCTAssertEqual((params["commands"] as? [String])?.first, "camera.snap")
        let clientObj = params["client"] as? [String: Any]
        XCTAssertEqual(clientObj?["mode"] as? String, "node")
        XCTAssertEqual(clientObj?["name"] as? String, "Super Meta")
    }

    func testOperatorConnectParams() {
        let client = makeClient(options: .operator)
        let params = client.connectParams(nonce: "n", signedAt: 1234)
        XCTAssertEqual(params["role"] as? String, "operator")
        XCTAssertEqual(params["minProtocol"] as? Int, 4)
        XCTAssertEqual(params["maxProtocol"] as? Int, 4)
        XCTAssertNil(params["caps"], "operator connect must not carry node-only fields")
        XCTAssertNil(params["commands"])
        XCTAssertEqual(params["scopes"] as? [String], ["operator.read", "operator.write"])
        let clientObj = params["client"] as? [String: Any]
        XCTAssertEqual(clientObj?["mode"] as? String, "operator")
        XCTAssertEqual(clientObj?["displayName"] as? String, "Super Meta")
        let auth = params["auth"] as? [String: Any]
        XCTAssertEqual(auth?["token"] as? String, "tok")
        XCTAssertNil(auth?["deviceToken"])
    }

    func testConnectParamsIncludePersistedDeviceToken() {
        let client = makeClient(options: .operator)
        client.setDeviceToken("issued-token")
        let params = client.connectParams(nonce: "n", signedAt: 1234)
        let auth = params["auth"] as? [String: Any]
        XCTAssertEqual(auth?["deviceToken"] as? String, "issued-token")
    }

    func testRequestResolvedByCorrelatedResponse() async throws {
        let client = makeClient(options: .operator)
        client.openForTesting()
        client.onOutgoingFrame = { frame in
            guard case let .request(id, method, _) = frame, method == "echo" else { return }
            let res = #"{"type":"res","id":"\#(id)","ok":true,"payload":{"answer":42}}"#
            Task { @MainActor in client.handleMessage(.string(res)) }
        }
        let payload = try await client.request(method: "echo")
        XCTAssertEqual(payload["answer"] as? Int, 42)
    }

    func testRequestRejectedByErrorResponse() async {
        let client = makeClient(options: .operator)
        client.openForTesting()
        client.onOutgoingFrame = { frame in
            guard case let .request(id, method, _) = frame, method == "echo" else { return }
            let res = #"{"type":"res","id":"\#(id)","ok":false,"error":{"code":"NOPE","message":"no"}}"#
            Task { @MainActor in client.handleMessage(.string(res)) }
        }
        do {
            _ = try await client.request(method: "echo")
            XCTFail("expected error")
        } catch let error as GatewayError {
            XCTAssertEqual(error.code, "NOPE")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testRequestTimesOut() async {
        let client = makeClient(options: .operator)
        client.openForTesting()
        do {
            _ = try await client.request(method: "echo", timeout: 0.05)
            XCTFail("expected timeout")
        } catch let error as GatewayError {
            XCTAssertEqual(error.code, "TIMEOUT")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testDisconnectFailsPendingRequests() async {
        let client = makeClient(options: .operator)
        client.openForTesting()
        client.onOutgoingFrame = { frame in
            guard case .request(_, "echo", _) = frame else { return }
            Task { @MainActor in client.disconnect() }
        }
        do {
            _ = try await client.request(method: "echo")
            XCTFail("expected disconnect error")
        } catch let error as GatewayError {
            XCTAssertEqual(error.code, "DISCONNECTED")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testRequestWithoutSocketThrows() async {
        let client = makeClient(options: .operator)
        do {
            _ = try await client.request(method: "echo")
            XCTFail("expected error")
        } catch let error as GatewayError {
            XCTAssertEqual(error.code, "DISCONNECTED")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testUnmatchedResponseIsDropped() {
        let client = makeClient(options: .operator)
        client.openForTesting()
        // A stray ping ack must not disturb connection state.
        client.handleMessage(.string(#"{"type":"res","id":"stray","ok":false,"error":{"code":"E","message":"x"}}"#))
        XCTAssertEqual(client.state, .disconnected)
    }

    func testEventsForwardedExceptChallenge() {
        let client = makeClient(options: .operator)
        var received: [(String, [String: Any])] = []
        client.onEvent = { received.append(($0, $1)) }
        client.handleMessage(.string(#"{"type":"event","event":"chat","payload":{"state":"delta"}}"#))
        client.handleMessage(.string(#"{"type":"event","event":"connect.challenge","payload":{"nonce":"n"}}"#))
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.0, "chat")
        XCTAssertEqual(received.first?.1["state"] as? String, "delta")
    }

    func testHelloOkCapturesDeviceToken() {
        let client = makeClient(options: .operator)
        client.openForTesting()
        var stored: String?
        client.onDeviceToken = { stored = $0 }
        // Trigger the connect request so connectRequestID is set, then answer it.
        var connectID: String?
        client.onOutgoingFrame = { frame in
            if case let .request(id, "connect", _) = frame { connectID = id }
        }
        client.handleMessage(.string(#"{"type":"event","event":"connect.challenge","payload":{"nonce":"n"}}"#))
        guard let connectID else { return XCTFail("connect frame not sent") }
        let res = #"{"type":"res","id":"\#(connectID)","ok":true,"payload":{"type":"hello-ok","protocol":4,"auth":{"deviceToken":"issued"}}}"#
        client.handleMessage(.string(res))
        XCTAssertEqual(client.state, .connected)
        XCTAssertEqual(stored, "issued")
        XCTAssertEqual(client.deviceToken, "issued")
    }

    func testConnectErrorNotPairedSetsWaitingState() {
        let client = makeClient(options: .operator)
        client.openForTesting()
        var connectID: String?
        client.onOutgoingFrame = { frame in
            if case let .request(id, "connect", _) = frame { connectID = id }
        }
        client.handleMessage(.string(#"{"type":"event","event":"connect.challenge","payload":{"nonce":"n"}}"#))
        guard let connectID else { return XCTFail("connect frame not sent") }
        let res = #"{"type":"res","id":"\#(connectID)","ok":false,"error":{"code":"NOT_PAIRED","message":"pair me"}}"#
        client.handleMessage(.string(res))
        XCTAssertEqual(client.state, .waitingForPairing)
    }
}
