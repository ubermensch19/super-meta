import XCTest
@testable import AIProviders

/// Live integration tests against the OpenAI API.
/// Skipped unless `OPENAI_API_KEY` is set in the environment.
final class OpenAILiveTests: XCTestCase {

    private var apiKey: String {
        get throws {
            guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
                throw XCTSkip("OPENAI_API_KEY not set — skipping live OpenAI test")
            }
            return key
        }
    }

    func testTextGeneration() async throws {
        let provider = OpenAIProvider(apiKey: try apiKey)
        let request = AIRequest(
            model: AIVendor.openAI.defaultModel,
            prompt: "Say hello in five words."
        )
        // Validates the transport: a successful, non-empty completion.
        let result = try await provider.generate(request)
        XCTAssertFalse(result.isEmpty, "Empty response from OpenAI")
    }

    func testVisionGeneration() async throws {
        let provider = OpenAIProvider(apiKey: try apiKey)
        let jpegBase64 = "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAB//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8A0s//2Q=="
        let image = AIImage(jpegData: Data(base64Encoded: jpegBase64)!)
        let request = AIRequest(
            model: AIVendor.openAI.defaultModel,
            prompt: "Briefly describe this image in one sentence.",
            images: [image]
        )
        let result = try await provider.generate(request)
        XCTAssertFalse(result.isEmpty)
        print("OPENAI_VISION_RESULT: \(result)")
    }
}
