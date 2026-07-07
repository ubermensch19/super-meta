import Foundation

/// Anthropic Claude via the Messages API (`api.anthropic.com/v1/messages`).
public struct ClaudeProvider: ChatVisionProvider {
    public let vendor: AIVendor = .claude
    private let apiKey: String
    private let session: URLSession
    private let version = "2023-06-01"

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func generate(_ request: AIRequest) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }

        let messages = request.messages.map { message -> [String: Any] in
            var content: [[String: Any]] = []
            for image in message.images {
                content.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": "image/jpeg", "data": image.base64]
                ])
            }
            if !message.text.isEmpty {
                content.append(["type": "text", "text": message.text])
            }
            return ["role": message.role.rawValue, "content": content]
        }

        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens ?? 1024,
            "messages": messages
        ]
        if let system = request.system { body["system"] = system }
        if let temperature = request.temperature { body["temperature"] = temperature }

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(version, forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await HTTP.send(urlRequest, session: session)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIProviderError.noContent
        }
        let text = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
        guard !text.isEmpty else { throw AIProviderError.noContent }
        return text
    }
}
