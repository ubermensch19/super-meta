import XCTest
@testable import AIProviders

final class ModelCatalogLiveTests: XCTestCase {

    func testGeminiModelList() async throws {
        guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("GEMINI_API_KEY not set")
        }
        let models = try await listModels(.gemini, apiKey: key)
        XCTAssertFalse(models.isEmpty, "Expected Gemini models")
        print("GEMINI_MODELS(\(models.count)): \(models.prefix(5).map(\.id))")
    }

    func testOpenAIModelList() async throws {
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        let models = try await listModels(.openAI, apiKey: key)
        XCTAssertFalse(models.isEmpty, "Expected OpenAI models")
        print("OPENAI_MODELS(\(models.count)): \(models.prefix(5).map(\.id))")
    }
}
