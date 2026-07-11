import XCTest
@testable import RealtimeVoice

final class RealtimeSessionUpdateTests: XCTestCase {

    func testSessionUpdateIncludesTools() throws {
        let tool = RealtimeTool(
            name: "hermes_ask",
            description: "Ask the agent",
            parametersJSON: #"{"type":"object","properties":{"question":{"type":"string"}},"required":["question"]}"#
        )
        let client = OpenAIRealtimeClient(apiKey: "test", config: .init(tools: [tool]))
        let session = client.sessionUpdateObject()

        XCTAssertEqual(session["tool_choice"] as? String, "auto")
        let tools = session["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 1)
        XCTAssertEqual(tools?.first?["type"] as? String, "function")
        XCTAssertEqual(tools?.first?["name"] as? String, "hermes_ask")
        let parameters = tools?.first?["parameters"] as? [String: Any]
        XCTAssertEqual(parameters?["type"] as? String, "object")
    }

    func testSessionUpdateOmitsToolsWhenEmpty() {
        let client = OpenAIRealtimeClient(apiKey: "test", config: .init())
        let session = client.sessionUpdateObject()
        XCTAssertNil(session["tools"])
        XCTAssertNil(session["tool_choice"])
    }
}

/// Live test: opens the OpenAI Realtime WebSocket and confirms the session
/// handshake (auth + protocol). Skipped unless OPENAI_API_KEY is set.
final class RealtimeHandshakeTests: XCTestCase {

    func testRealtimeSessionHandshake() async throws {
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set — skipping live realtime handshake test")
        }
        let client = OpenAIRealtimeClient(apiKey: key, config: .init(audio: true))
        client.connect()
        defer { client.disconnect() }

        // Wait up to 15s for session.created (or an error).
        let deadline = Date().addingTimeInterval(15)
        var sawSessionCreated = false
        for await event in client.events {
            switch event {
            case .sessionCreated, .sessionUpdated:
                sawSessionCreated = true
            case let .error(message):
                XCTFail("Realtime error: \(message)")
                return
            default:
                break
            }
            if sawSessionCreated || Date() > deadline { break }
        }
        XCTAssertTrue(sawSessionCreated, "Did not receive session.created within timeout")
    }
}
