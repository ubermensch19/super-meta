import SwiftUI
import DesignSystem
import AIProviders
import GlassesKit

struct SettingsView: View {
    @EnvironmentObject private var providers: ProviderManager
    @EnvironmentObject private var glasses: GlassesService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                providerSection
                keysSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var deviceSection: some View {
        Section {
            HStack {
                Text("Glasses")
                Spacer()
                StatusBadge(
                    glasses.isAvailable ? (glasses.hasActiveDevice ? "connected" : "registered") : "unavailable",
                    color: glasses.hasActiveDevice ? Theme.Palette.positive : Theme.Palette.textMuted
                )
            }
        } header: { sectionHeader("Device") }
        .listRowBackground(Theme.Palette.surface)
        .foregroundStyle(Theme.Palette.textPrimary)
    }

    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $providers.visionVendor) {
                ForEach(AIVendor.allCases, id: \.self) { vendor in
                    Text(vendor.displayName).tag(vendor)
                }
            }
            .tint(Theme.Palette.accent)

            NavigationLink {
                ModelPickerView(vendor: providers.visionVendor)
            } label: {
                HStack {
                    Text("Model")
                    Spacer()
                    Text(providers.model(for: providers.visionVendor))
                        .font(Theme.Font.readout(12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        } header: { sectionHeader("AI Provider") } footer: {
            Text("Used for image recognition and chat. Realtime voice uses OpenAI.")
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .listRowBackground(Theme.Palette.surface)
        .foregroundStyle(Theme.Palette.textPrimary)
    }

    private var keysSection: some View {
        Section {
            ForEach(AIVendor.allCases, id: \.self) { vendor in
                NavigationLink {
                    APIKeyEntryView(vendor: vendor)
                } label: {
                    HStack {
                        Text(vendor.displayName)
                        Spacer()
                        if providers.hasKey(for: vendor) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Palette.positive)
                        } else {
                            Text("not set")
                                .font(Theme.Font.readout(12))
                                .foregroundStyle(Theme.Palette.textMuted)
                        }
                    }
                }
            }
        } header: { sectionHeader("API Keys") }
        .listRowBackground(Theme.Palette.surface)
        .foregroundStyle(Theme.Palette.textPrimary)
    }

    private var aboutSection: some View {
        Section {
            HStack { Text("Version"); Spacer(); Text("0.0.1").foregroundStyle(Theme.Palette.textSecondary) }
        } header: { sectionHeader("About") }
        .listRowBackground(Theme.Palette.surface)
        .foregroundStyle(Theme.Palette.textPrimary)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.Font.readout(11))
            .tracking(1.5)
            .foregroundStyle(Theme.Palette.textSecondary)
    }
}

/// Secure entry for one vendor's API key.
struct APIKeyEntryView: View {
    let vendor: AIVendor
    @EnvironmentObject private var providers: ProviderManager
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        List {
            Section {
                SecureField("Paste your \(vendor.displayName) API key", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.Palette.textPrimary)
            } footer: {
                Text(footerHint).foregroundStyle(Theme.Palette.textMuted)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Button("Save") {
                    providers.setAPIKey(draft, for: vendor)
                    dismiss()
                }
                .foregroundStyle(Theme.Palette.accent)
                if providers.hasKey(for: vendor) {
                    Button("Remove key", role: .destructive) {
                        providers.setAPIKey("", for: vendor)
                        draft = ""
                        dismiss()
                    }
                }
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle(vendor.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = providers.apiKey(for: vendor) }
        .preferredColorScheme(.dark)
    }

    private var footerHint: String {
        switch vendor {
        case .gemini: return "Get a key at aistudio.google.com/apikey"
        case .openAI: return "Get a key at platform.openai.com/api-keys"
        case .claude: return "Get a key at console.anthropic.com"
        case .openRouter: return "Get a key at openrouter.ai/keys"
        }
    }
}

/// Simple model id editor (free text + the vendor default).
struct ModelPickerView: View {
    let vendor: AIVendor
    @EnvironmentObject private var providers: ProviderManager
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        List {
            Section {
                TextField("Model id", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.Palette.textPrimary)
                Button("Use default (\(vendor.defaultModel))") { draft = vendor.defaultModel }
                    .foregroundStyle(Theme.Palette.accent)
            } footer: {
                Text("Must be a vision-capable model for image features.")
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Button("Save") {
                    providers.setModel(draft.isEmpty ? vendor.defaultModel : draft, for: vendor)
                    dismiss()
                }
                .foregroundStyle(Theme.Palette.accent)
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("\(vendor.displayName) Model")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = providers.model(for: vendor) }
        .preferredColorScheme(.dark)
    }
}
