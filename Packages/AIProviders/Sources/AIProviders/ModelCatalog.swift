import Foundation

public struct AIModelInfo: Identifiable, Sendable, Equatable, Comparable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static func < (lhs: AIModelInfo, rhs: AIModelInfo) -> Bool { lhs.id < rhs.id }
}

/// Fetches the list of models a provider exposes for the given API key.
public func listModels(_ vendor: AIVendor, apiKey: String, session: URLSession = .shared) async throws -> [AIModelInfo] {
    guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
    switch vendor {
    case .gemini:     return try await listGeminiModels(apiKey: apiKey, session: session)
    case .openAI:     return try await listOpenAIModels(apiKey: apiKey, session: session)
    case .claude:     return try await listClaudeModels(apiKey: apiKey, session: session)
    case .openRouter: return try await listOpenRouterModels(apiKey: apiKey, session: session)
    }
}

private func listGeminiModels(apiKey: String, session: URLSession) async throws -> [AIModelInfo] {
    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)&pageSize=200")!
    let data = try await HTTP.send(URLRequest(url: url), session: session)
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let models = json["models"] as? [[String: Any]] else { return [] }
    return models.compactMap { entry -> AIModelInfo? in
        guard let fullName = entry["name"] as? String else { return nil }
        let methods = entry["supportedGenerationMethods"] as? [String] ?? []
        guard methods.contains("generateContent") else { return nil }
        let id = fullName.replacingOccurrences(of: "models/", with: "")
        let display = entry["displayName"] as? String ?? id
        return AIModelInfo(id: id, name: display)
    }.sorted()
}

private func listOpenAIModels(apiKey: String, session: URLSession) async throws -> [AIModelInfo] {
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    let data = try await HTTP.send(request, session: session)
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let models = json["data"] as? [[String: Any]] else { return [] }
    let excluded = ["whisper", "tts", "embedding", "dall-e", "moderation", "audio", "image", "transcribe", "search", "babbage", "davinci"]
    return models.compactMap { entry -> AIModelInfo? in
        guard let id = entry["id"] as? String else { return nil }
        if excluded.contains(where: id.contains) { return nil }
        return AIModelInfo(id: id, name: id)
    }.sorted()
}

private func listClaudeModels(apiKey: String, session: URLSession) async throws -> [AIModelInfo] {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=100")!)
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    let data = try await HTTP.send(request, session: session)
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let models = json["data"] as? [[String: Any]] else { return [] }
    return models.compactMap { entry -> AIModelInfo? in
        guard let id = entry["id"] as? String else { return nil }
        return AIModelInfo(id: id, name: entry["display_name"] as? String ?? id)
    }.sorted()
}

private func listOpenRouterModels(apiKey: String, session: URLSession) async throws -> [AIModelInfo] {
    var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    let data = try await HTTP.send(request, session: session)
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let models = json["data"] as? [[String: Any]] else { return [] }
    return models.compactMap { entry -> AIModelInfo? in
        guard let id = entry["id"] as? String else { return nil }
        return AIModelInfo(id: id, name: entry["name"] as? String ?? id)
    }.sorted()
}
