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

    /// Per-vendor selected model id.
    @Published private(set) var models: [AIVendor: String]

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let visionVendor = "vision_vendor"
        static func model(_ v: AIVendor) -> String { "model_\(v.rawValue)" }
        static func key(_ v: AIVendor) -> String { "apikey_\(v.rawValue)" }
    }

    private init() {
        let savedVendor = defaults.string(forKey: Keys.visionVendor).flatMap(AIVendor.init) ?? .gemini
        self.visionVendor = savedVendor
        var loaded: [AIVendor: String] = [:]
        for vendor in AIVendor.allCases {
            loaded[vendor] = defaults.string(forKey: Keys.model(vendor)) ?? vendor.defaultModel
        }
        self.models = loaded
    }

    // MARK: Models

    func model(for vendor: AIVendor) -> String {
        models[vendor] ?? vendor.defaultModel
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

    // MARK: Active provider

    /// The provider to use for vision/chat features, or nil if no key is set.
    func visionProvider() -> ChatVisionProvider? {
        let key = apiKey(for: visionVendor)
        guard !key.isEmpty else { return nil }
        return makeProvider(visionVendor, apiKey: key)
    }

    func currentModel() -> String { model(for: visionVendor) }
}
