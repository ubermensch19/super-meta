import Foundation

// MARK: - Vendor-neutral request/response model

/// A JPEG image to send to a multimodal model.
public struct AIImage: Sendable, Equatable {
    public let jpegData: Data
    public init(jpegData: Data) { self.jpegData = jpegData }

    var base64: String { jpegData.base64EncodedString() }
}

/// One turn in a conversation. For most features a single `.user` message is enough.
public struct AIMessage: Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public let role: Role
    public let text: String
    public let images: [AIImage]

    public init(role: Role = .user, text: String, images: [AIImage] = []) {
        self.role = role
        self.text = text
        self.images = images
    }
}

/// A vendor-neutral generation request.
public struct AIRequest: Sendable {
    public var model: String
    public var system: String?
    public var messages: [AIMessage]
    public var maxTokens: Int?
    public var temperature: Double?

    public init(
        model: String,
        system: String? = nil,
        messages: [AIMessage],
        maxTokens: Int? = 1024,
        temperature: Double? = nil
    ) {
        self.model = model
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    /// Convenience for the common "one prompt + optional images" case.
    public init(
        model: String,
        system: String? = nil,
        prompt: String,
        images: [AIImage] = [],
        maxTokens: Int? = 1024
    ) {
        self.init(
            model: model,
            system: system,
            messages: [AIMessage(role: .user, text: prompt, images: images)],
            maxTokens: maxTokens
        )
    }
}

// MARK: - Errors

public enum AIProviderError: Error, LocalizedError {
    case missingAPIKey
    case badResponse(status: Int, body: String)
    case decoding(String)
    case noContent

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No API key configured for this provider."
        case let .badResponse(status, body): return "Provider returned HTTP \(status): \(body)"
        case let .decoding(detail): return "Could not parse provider response: \(detail)"
        case .noContent: return "Provider returned an empty response."
        }
    }
}

// MARK: - Provider abstraction

/// Identifies a supported vendor. Each maps to a concrete `ChatVisionProvider`.
public enum AIVendor: String, CaseIterable, Sendable, Codable {
    case gemini
    case openAI
    case claude
    case openRouter

    public var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI"
        case .claude: return "Anthropic Claude"
        case .openRouter: return "OpenRouter"
        }
    }

    /// A sensible default multimodal model id. All are user-overridable.
    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-2.5-flash"
        case .openAI: return "gpt-4o"
        case .claude: return "claude-3-5-sonnet-latest"
        case .openRouter: return "google/gemini-2.5-flash"
        }
    }
}

/// A multimodal chat/vision provider. Features depend only on this protocol,
/// never on a concrete vendor.
public protocol ChatVisionProvider: Sendable {
    var vendor: AIVendor { get }
    func generate(_ request: AIRequest) async throws -> String
}

public extension ChatVisionProvider {
    /// Builds the concrete client for a vendor + API key.
    static func make(vendor: AIVendor, apiKey: String, session: URLSession = .shared) -> ChatVisionProvider {
        switch vendor {
        case .gemini: return GeminiProvider(apiKey: apiKey, session: session)
        case .openAI: return OpenAIProvider(apiKey: apiKey, session: session)
        case .claude: return ClaudeProvider(apiKey: apiKey, session: session)
        case .openRouter: return OpenRouterProvider(apiKey: apiKey, session: session)
        }
    }
}

/// Free function form of the factory (no need for a concrete type to call it).
public func makeProvider(_ vendor: AIVendor, apiKey: String, session: URLSession = .shared) -> ChatVisionProvider {
    switch vendor {
    case .gemini: return GeminiProvider(apiKey: apiKey, session: session)
    case .openAI: return OpenAIProvider(apiKey: apiKey, session: session)
    case .claude: return ClaudeProvider(apiKey: apiKey, session: session)
    case .openRouter: return OpenRouterProvider(apiKey: apiKey, session: session)
    }
}

// MARK: - Shared HTTP helper

enum HTTP {
    static func send(_ request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.badResponse(status: -1, body: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw AIProviderError.badResponse(status: http.statusCode, body: String(body.prefix(800)))
        }
        return data
    }
}
