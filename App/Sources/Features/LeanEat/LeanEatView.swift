import SwiftUI
import SwiftData
import DesignSystem
import Inject

struct LeanEatView: View {
    @EnvironmentObject private var providers: ProviderManager
    @Environment(\.modelContext) private var context
    @ObserveInjection var inject

    @State private var image: UIImage?
    @State private var result = ""
    @State private var error: String?
    @State private var busy = false

    private let prompt = """
    You are a nutrition assistant. Identify the food and drink in this image. \
    Respond in this exact format:
    Food: <items>
    Calories: <approx kcal>
    Protein / Carbs / Fat: <grams each>
    Health score: <1-10>
    Tip: <one short suggestion>
    """

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ImageSourceView(image: $image)

                HUDButton(busy ? "Analyzing…" : "Analyze nutrition", systemImage: "leaf") {
                    Task { await analyze() }
                }
                .disabled(image == nil || busy)
                .opacity(image == nil ? 0.5 : 1)

                if let error {
                    HUDPanel { Text(error).font(Theme.Font.body(14)).foregroundStyle(Theme.Palette.live) }
                } else if !result.isEmpty {
                    HUDPanel {
                        Text(result).font(Theme.Font.body(15)).foregroundStyle(Theme.Palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("LeanEat")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .enableInjection()
    }

    private func analyze() async {
        guard let image else { return }
        busy = true; defer { busy = false }
        error = nil
        let outcome = await VisionAnalyzer.run(prompt: prompt, image: image, kind: .leanEat, providers: providers, context: context)
        result = outcome.text ?? ""
        error = outcome.error
    }
}
