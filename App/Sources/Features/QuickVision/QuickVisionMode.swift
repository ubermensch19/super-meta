import Foundation

/// Preset recognition modes. Each maps to a system/user prompt sent with the image.
enum QuickVisionMode: String, CaseIterable, Identifiable {
    case standard, health, blind, reading, translate, encyclopedia, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Describe"
        case .health: return "Food Health"
        case .blind: return "Accessibility"
        case .reading: return "Read Text"
        case .translate: return "Translate"
        case .encyclopedia: return "Identify"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "eye"
        case .health: return "leaf"
        case .blind: return "figure.walk"
        case .reading: return "text.viewfinder"
        case .translate: return "globe"
        case .encyclopedia: return "book"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// The prompt for this mode. `custom` uses the user's text; `translate` injects a target language.
    func prompt(custom: String = "", targetLanguage: String = "English") -> String {
        switch self {
        case .standard:
            return "Describe what is in this image clearly and concisely."
        case .health:
            return "Identify the food or drink in this image and assess how healthy it is. Note approximate calories and key nutrition points."
        case .blind:
            return "You are assisting a visually impaired person. Describe the scene, important objects, any text, and potential hazards in clear, practical terms."
        case .reading:
            return "Read all text visible in this image aloud, preserving order. If there is no text, say so."
        case .translate:
            return "Identify any text in this image and translate it into \(targetLanguage). Provide only the translation."
        case .encyclopedia:
            return "Identify the main subject of this image and give a brief, encyclopedic description of what it is."
        case .custom:
            return custom.isEmpty ? "Describe this image." : custom
        }
    }
}
