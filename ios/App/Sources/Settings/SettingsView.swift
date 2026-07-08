import SwiftUI
import DesignSystem
import AIProviders
import GlassesKit
import Inject

struct SettingsView: View {
    @EnvironmentObject private var providers: ProviderManager
    @EnvironmentObject private var glasses: GlassesService
    @EnvironmentObject private var wakeListener: WakeWordListener
    @Environment(\.dismiss) private var dismiss
    @State private var useCustomModel = false
    @State private var modelChoice = "gpt-realtime"
    @ObserveInjection var inject

    private let customTag = "__custom__"

    var body: some View {
        NavigationStack {
            List {
                deviceSection
                providerSection
                voiceSection
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
        .enableInjection()
        .onAppear {
            useCustomModel = !ProviderManager.knownRealtimeModels.contains(providers.realtimeModel)
            modelChoice = useCustomModel ? customTag : providers.realtimeModel
        }
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
            Text("Used for image recognition and chat. Realtime voice uses OpenAI — pick its model under Voice.")
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .listRowBackground(Theme.Palette.surface)
        .foregroundStyle(Theme.Palette.textPrimary)
    }

    private var voiceSection: some View {
        Section {
            Picker("Realtime model", selection: $modelChoice) {
                ForEach(ProviderManager.knownRealtimeModels, id: \.self) { Text($0).tag($0) }
                Text("Custom").tag(customTag)
            }
            .tint(Theme.Palette.accent)
            .onChange(of: modelChoice) { _, choice in
                if choice == customTag {
                    useCustomModel = true
                } else {
                    useCustomModel = false
                    providers.realtimeModel = choice
                }
            }

            if useCustomModel {
                TextField("Model id, e.g. gpt-realtime-2", text: $providers.realtimeModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.Palette.textPrimary)
            }

            Toggle("Wake word", isOn: $wakeListener.enabled)
                .tint(Theme.Palette.accent)

            if wakeListener.enabled {
                TextField("Wake phrase, e.g. hey neo", text: $wakeListener.phrase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        } header: { sectionHeader("Voice") } footer: {
            Text("Say the wake phrase to start Live AI hands-free on your selected model — through the glasses when connected, even with the phone locked. Keeps the mic active; uses more battery. Camera context pauses while the app is in the background.")
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

/// Fetches and lists every model the provider exposes; tap to select.
/// Falls back to manual entry if there's no key or the fetch fails.
struct ModelPickerView: View {
    let vendor: AIVendor
    @EnvironmentObject private var providers: ProviderManager
    @Environment(\.dismiss) private var dismiss

    @State private var models: [AIModelInfo] = []
    @State private var loading = false
    @State private var loadError: String?
    @State private var search = ""
    @State private var manual = ""

    private var filtered: [AIModelInfo] {
        guard !search.isEmpty else { return models }
        return models.filter { $0.id.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if loading {
                Section { HStack { ProgressView().tint(Theme.Palette.accent); Text("Loading models…").foregroundStyle(Theme.Palette.textSecondary) } }
                    .listRowBackground(Theme.Palette.surface)
            }

            if let loadError {
                Section {
                    Text(loadError).font(Theme.Font.body(14)).foregroundStyle(Theme.Palette.live)
                    TextField("Model id", text: $manual)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Button("Use \"\(manual.isEmpty ? vendor.defaultModel : manual)\"") {
                        providers.setModel(manual.isEmpty ? vendor.defaultModel : manual, for: vendor); dismiss()
                    }.foregroundStyle(Theme.Palette.accent)
                } header: { Text("Manual entry") }
                .listRowBackground(Theme.Palette.surface)
            }

            if !models.isEmpty {
                Section {
                    ForEach(filtered) { model in
                        Button { providers.setModel(model.id, for: vendor); dismiss() } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name).foregroundStyle(Theme.Palette.textPrimary)
                                    if model.name != model.id {
                                        Text(model.id).font(Theme.Font.readout(11)).foregroundStyle(Theme.Palette.textMuted)
                                    }
                                }
                                Spacer()
                                if providers.model(for: vendor) == model.id {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.Palette.accent)
                                }
                            }
                        }
                    }
                } header: { Text("\(models.count) models") }
                .listRowBackground(Theme.Palette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("\(vendor.displayName) Model")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Filter models")
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private func load() async {
        let key = providers.apiKey(for: vendor)
        manual = providers.model(for: vendor)
        guard !key.isEmpty else {
            loadError = "Add your \(vendor.displayName) API key first to load the model list."
            return
        }
        loading = true
        defer { loading = false }
        do {
            models = try await listModels(vendor, apiKey: key)
            if models.isEmpty { loadError = "No models returned." }
        } catch {
            loadError = (error as? AIProviderError)?.errorDescription ?? error.localizedDescription
        }
    }
}
