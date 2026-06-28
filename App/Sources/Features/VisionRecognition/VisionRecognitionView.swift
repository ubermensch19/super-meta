import SwiftUI
import SwiftData
import DesignSystem
import Inject

struct VisionRecognitionView: View {
    @EnvironmentObject private var providers: ProviderManager
    @Environment(\.modelContext) private var context
    @ObserveInjection var inject

    @State private var image: UIImage?
    @State private var prompt = ""
    @State private var result = ""
    @State private var error: String?
    @State private var busy = false

    private let suggestions = [
        "What is in this image?",
        "Describe this in detail",
        "What objects do you see?",
        "Where might this be?",
        "Read any text you see"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ImageSourceView(image: $image)

                TextField("Ask anything about the image…", text: $prompt, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .foregroundStyle(Theme.Palette.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { prompt = s }
                                .font(Theme.Font.readout(12))
                                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.sm)
                                .background(Capsule().fill(Theme.Palette.surface))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .buttonStyle(.plain)
                        }
                    }
                }

                HUDButton(busy ? "Thinking…" : "Ask", systemImage: "sparkles") {
                    Task { await ask() }
                }
                .disabled(image == nil || prompt.isEmpty || busy)
                .opacity(image == nil || prompt.isEmpty ? 0.5 : 1)

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
        .navigationTitle("Vision Chat")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .enableInjection()
    }

    private func ask() async {
        guard let image else { return }
        busy = true; defer { busy = false }
        error = nil
        let outcome = await VisionAnalyzer.run(prompt: prompt, image: image, kind: .visionRecognition, providers: providers, context: context)
        result = outcome.text ?? ""
        error = outcome.error
    }
}
