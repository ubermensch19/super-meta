import XCTest
@testable import RealtimeVoice

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
