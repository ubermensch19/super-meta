import SwiftUI
import SwiftData
import AIProviders
import GlassesKit

/// Shared image-analysis pipeline used by the vision features. Resolves the
/// active provider, sends the image + prompt, returns text, and persists a record.
@MainActor
enum VisionAnalyzer {
    struct Outcome {
        var text: String?
        var error: String?
    }

    static func run(
        prompt: String,
        image: UIImage,
        kind: VisionRecordKind,
        providers: ProviderManager,
        context: ModelContext
    ) async -> Outcome {
        guard let provider = providers.visionProvider() else {
            return Outcome(error: "No API key set for \(providers.visionVendor.displayName). Add one in Settings.")
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else {
            return Outcome(error: "Could not encode the image.")
        }
        let request = AIRequest(
            model: providers.currentModel(),
            prompt: prompt,
            images: [AIImage(jpegData: jpeg)]
        )
        do {
            let text = try await provider.generate(request)
            let thumb = image.scaledForThumbnail().jpegData(compressionQuality: 0.5)
            context.insert(VisionRecord(kind: kind, prompt: prompt, result: text, thumbnail: thumb))
            return Outcome(text: text)
        } catch {
            let message = (error as? AIProviderError)?.errorDescription ?? error.localizedDescription
            return Outcome(error: message)
        }
    }
}
