import Foundation
import SwiftUI
import AIProviders

/// Owns the user's AI provider selection and API keys, and builds the active
/// `ChatVisionProvider` for vision/chat features. Keys live in the Keychain;
/// vendor + per-vendor model live in UserDefaults.
@MainActor
final class ProviderManager: ObservableObject {
    static let shared = ProviderManager()

    @Published var visionVendor: AIVendor {
        didSet { defaults.set(visionVendor.rawValue, forKey: Keys.visionVendor) }
    }

    /// Which provider powers Live AI realtime voice. Default: Gemini Live.
    @Published var realtimeVendor: AIVendor {
        didSet { defaults.set(realtimeVendor.rawValue, forKey: Keys.realtimeVendor) }
    }

    /// The realtime model Live AI / Live Translate connect to (per current vendor).
    @Published var realtimeModel: String {
        didSet { defaults.set(realtimeModel, forKey: Keys.realtimeModel) }
    }

    /// Curated realtime model ids offered in Settings; a custom id can also be typed.
    static let knownRealtimeModels = ["gemini-3.1-flash-live-preview", "gemini-2.5-flash-native-audio-latest", "gemini-3.5-live-translate-preview", "gpt-realtime", "gpt-realtime-2"]

    /// Per-vendor selected model id.
    @Published private(set) var models: [AIVendor: String]

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let visionVendor = "vision_vendor"
        static let realtimeVendor = "realtime_vendor"
        static let realtimeModel = "realtime_model"
        static func model(_ v: AIVendor) -> String { "model_\(v.rawValue)" }
        static func key(_ v: AIVendor) -> String { "apikey_\(v.rawValue)" }
    }

    private init() {
        let savedVendor = defaults.string(forKey: Keys.visionVendor).flatMap(AIVendor.init) ?? .gemini
        self.visionVendor = savedVendor
        let savedRealtimeVendor = defaults.string(forKey: Keys.realtimeVendor).flatMap(AIVendor.init) ?? .gemini
        self.realtimeVendor = savedRealtimeVendor
        var rtModel = defaults.string(forKey: Keys.realtimeModel) ?? "gemini-2.5-flash-native-audio-latest"
        // Keep the model consistent with the vendor so a value persisted before the
        // Gemini switch (e.g. "gpt-realtime-2") can't pair with the Gemini client.
        if savedRealtimeVendor == .gemini, !rtModel.lowercased().contains("gemini") {
            rtModel = "gemini-2.5-flash-native-audio-latest"
        } else if savedRealtimeVendor == .openAI, rtModel.lowercased().contains("gemini") {
            rtModel = "gpt-realtime"
        }
        self.realtimeModel = rtModel
        var loaded: [AIVendor: String] = [:]
        for vendor in AIVendor.allCases {
            loaded[vendor] = defaults.string(forKey: Keys.model(vendor)) ?? vendor.defaultModel
        }
        self.models = loaded
    }

    // MARK: Models

    /// Model ids that only work on non-chat endpoints (Realtime/audio/etc.). If one
    /// was ever selected for vision, fall back to the vendor's default chat model so
    /// requests don't 404 with "This is not a chat model."
    private static let nonChatMarkers = ["realtime", "audio", "tts", "whisper", "embedding", "transcribe", "dall-e", "image"]

    func model(for vendor: AIVendor) -> String {
        let saved = models[vendor] ?? vendor.defaultModel
        if Self.nonChatMarkers.contains(where: saved.lowercased().contains) { return vendor.defaultModel }
        return saved
    }

    func setModel(_ model: String, for vendor: AIVendor) {
        models[vendor] = model
        defaults.set(model, forKey: Keys.model(vendor))
    }

    // MARK: API keys (Keychain)

    func apiKey(for vendor: AIVendor) -> String {
        KeychainStore.get(Keys.key(vendor)) ?? ""
    }

    func setAPIKey(_ key: String, for vendor: AIVendor) {
        KeychainStore.set(key, for: Keys.key(vendor))
        objectWillChange.send()
    }

    func hasKey(for vendor: AIVendor) -> Bool {
        !apiKey(for: vendor).isEmpty
    }

    /// API key for the realtime voice provider. Falls back to the bundled Gemini
    /// Live key (from Config/Secrets.xcconfig → Info.plist) when the user hasn't
    /// entered one, so Live AI works out of the box on Gemini.
    func realtimeAPIKey() -> String {
        let saved = apiKey(for: realtimeVendor)
        if !saved.isEmpty { return saved }
        if realtimeVendor == .gemini {
            return (Bundle.main.object(forInfoDictionaryKey: "GeminiLiveKey") as? String) ?? ""
        }
        return ""
    }

    // MARK: Active provider

    /// The provider to use for vision/chat features, or nil if no key is set.
    func visionProvider() -> ChatVisionProvider? {
        let key = apiKey(for: visionVendor)
        guard !key.isEmpty else { return nil }
        return makeProvider(visionVendor, apiKey: key)
    }

    func currentModel() -> String { model(for: visionVendor) }
}
