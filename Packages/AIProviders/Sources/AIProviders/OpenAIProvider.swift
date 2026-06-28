import Foundation

/// OpenAI-compatible chat/completions client. Shared by OpenAI and OpenRouter,
/// which expose the same wire format (messages with text + image_url content parts).
struct OpenAICompatibleClient {
    let apiKey: String
    let session: URLSession
    let endpoint: URL
    let extraHeaders: [String: String]

    func generate(_ request: AIRequest) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }

        var messages: [[String: Any]] = []
        if let system = request.system {
            messages.append(["role": "system", "content": system])
        }
        for message in request.messages {
            var content: [[String: Any]] = []
            if !message.text.isEmpty {
                content.append(["type": "text", "text": message.text])
            }
            for image in message.images {
                content.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(image.base64)"]
                ])
            }
            messages.append(["role": message.role.rawValue, "content": content])
        }

        var body: [String: Any] = ["model": request.model, "messages": messages]
        if let maxTokens = request.maxTokens { body["max_tokens"] = maxTokens }
        if let temperature = request.temperature { body["temperature"] = temperature }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in extraHeaders { urlRequest.setValue(value, forHTTPHeaderField: key) }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await HTTP.send(urlRequest, session: session)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String, !text.isEmpty else {
            throw AIProviderError.noContent
        }
        return text
    }
}

/// OpenAI (`api.openai.com`).
public struct OpenAIProvider: ChatVisionProvider {
    public let vendor: AIVendor = .openAI
    private let client: OpenAICompatibleClient

    public init(apiKey: String, session: URLSession = .shared) {
        self.client = OpenAICompatibleClient(
            apiKey: apiKey,
            session: session,
            endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
            extraHeaders: [:]
        )
    }

    public func generate(_ request: AIRequest) async throws -> String {
        try await client.generate(request)
    }
}

/// OpenRouter (`openrouter.ai`) — OpenAI-compatible, fronts many vendors' models.
public struct OpenRouterProvider: ChatVisionProvider {
    public let vendor: AIVendor = .openRouter
    private let apiKey: String
    private let session: URLSession
    private let client: OpenAICompatibleClient

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
        self.client = OpenAICompatibleClient(
            apiKey: apiKey,
            session: session,
            endpoint: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            extraHeaders: [
                "HTTP-Referer": "https://github.com/priyanshu/meta-mod",
                "X-Title": "Meta-Mod"
            ]
        )
    }

    public func generate(_ request: AIRequest) async throws -> String {
        try await client.generate(request)
    }

    /// Fetches the vision-capable model catalog for the model picker UI.
    public func listVisionModels() async throws -> [OpenRouterModel] {
        var urlRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let data = try await HTTP.send(urlRequest, session: session)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            throw AIProviderError.decoding("model list")
        }
        return models.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let modality = ((entry["architecture"] as? [String: Any])?["modality"] as? String) ?? ""
            let inputModalities = ((entry["architecture"] as? [String: Any])?["input_modalities"] as? [String]) ?? []
            let supportsImage = modality.contains("image") || inputModalities.contains("image")
            guard supportsImage else { return nil }
            return OpenRouterModel(id: id, name: entry["name"] as? String ?? id)
        }
    }
}

public struct OpenRouterModel: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
}
