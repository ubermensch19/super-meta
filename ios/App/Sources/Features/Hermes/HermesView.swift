import SwiftUI
import DesignSystem
import AgentGateway
import Inject

/// Command center for the OpenClaw/Hermes agent: chat with streamed replies,
/// running sessions at a glance, and quick actions to spawn tasks or send
/// messages through the agent's channels.
struct HermesView: View {
    @EnvironmentObject private var hermes: HermesService
    @EnvironmentObject private var gateway: GatewayService
    @ObserveInjection var inject

    @State private var draft = ""
    @State private var errorText: String?
    @State private var showPairing = false
    @State private var showTaskSheet = false
    @State private var showMessageSheet = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

            if !hermes.sessions.isEmpty {
                sessionStrip
                    .padding(.top, Theme.Spacing.md)
            }

            transcript

            if let errorText {
                Text(errorText)
                    .font(Theme.Font.body(12))
                    .foregroundStyle(Theme.Palette.live)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xs)
            }

            quickActions
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)

            inputBar
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)
        }
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Hermes")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showPairing) { HermesPairingView() }
        .sheet(isPresented: $showTaskSheet) { SpawnTaskSheet() }
        .sheet(isPresented: $showMessageSheet) { ChannelMessageSheet() }
        .enableInjection()
        .onAppear {
            if hermes.isConfigured {
                hermes.connect()
                Task { await hermes.refreshSessions() }
            } else {
                showPairing = true
            }
        }
        .onChange(of: hermes.state) { _, newState in
            // Pairing rejections need user action on the gateway — surface the steps.
            if newState == .waitingForPairing { showPairing = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            StatusBadge(statusLabel, color: statusColor)
            Spacer()
            if hermes.state != .connected {
                Button("Pair") { showPairing = true }
                    .font(Theme.Font.readout(13))
                    .foregroundStyle(Theme.Palette.accent)
            } else {
                Button {
                    Task { await hermes.refreshSessions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private var statusLabel: String {
        switch hermes.state {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .waitingForPairing: return "awaiting approval"
        case .error: return "error"
        }
    }

    private var statusColor: Color {
        switch hermes.state {
        case .connected: return Theme.Palette.positive
        case .connecting, .waitingForPairing: return Theme.Palette.accent
        case .error: return Theme.Palette.live
        case .disconnected: return Theme.Palette.textMuted
        }
    }

    // MARK: Sessions

    private var sessionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(hermes.sessions) { session in
                    sessionChip(session)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private func sessionChip(_ session: AgentSessionInfo) -> some View {
        let focused = sessionKeysMatch(session.key, hermes.focusedSessionKey)
        return Button {
            hermes.focusedSessionKey = session.key
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(session.status == "active" ? Theme.Palette.positive : Theme.Palette.textMuted)
                    .frame(width: 6, height: 6)
                Text(session.label)
                    .font(Theme.Font.readout(12))
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(focused ? Theme.Palette.accent.opacity(0.22) : Theme.Palette.surface)
            )
            .overlay(
                Capsule().strokeBorder(focused ? Theme.Palette.accent : .clear, lineWidth: 1)
            )
            .foregroundStyle(focused ? Theme.Palette.accent : Theme.Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    if hermes.messages.isEmpty && hermes.streamingReply.isEmpty {
                        emptyState.padding(.top, Theme.Spacing.xl)
                    }
                    ForEach(hermes.messages) { message in
                        bubble(message)
                    }
                    if !hermes.streamingReply.isEmpty {
                        streamingBubble.id("streaming")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(Theme.Spacing.lg)
            }
            .onChange(of: hermes.messages) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: hermes.streamingReply) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "command")
                .font(.system(size: 28))
                .foregroundStyle(Theme.Palette.textMuted)
            Text("Ask hermes anything, spawn a task,\nor send a message through its channels.")
                .font(Theme.Font.body(13))
                .foregroundStyle(Theme.Palette.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func bubble(_ message: HermesChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(Theme.Font.body(15))
                .foregroundStyle(message.role == .system ? Theme.Palette.textMuted : Theme.Palette.textPrimary)
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(message.role == .user ? Theme.Palette.accent.opacity(0.18) : Theme.Palette.surface)
                )
            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    private var streamingBubble: some View {
        HStack {
            Text(hermes.streamingReply)
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.Palette.surface)
                )
                .overlay(alignment: .bottomTrailing) {
                    ProgressView().scaleEffect(0.5).padding(6)
                }
            Spacer(minLength: 40)
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: Theme.Spacing.sm) {
            quickAction("New Task", "hammer") { showTaskSheet = true }
            quickAction("Send Message", "paperplane") { showMessageSheet = true }
            quickAction("Status", "list.bullet.rectangle") {
                Task { await hermes.refreshSessions() }
            }
        }
    }

    private func quickAction(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                Text(title).font(Theme.Font.readout(12))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.Palette.surface))
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Message hermes…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .foregroundStyle(Theme.Palette.textPrimary)
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.isEmpty ? Theme.Palette.textMuted : Theme.Palette.accent)
            }
            .disabled(draft.isEmpty)
        }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        errorText = nil
        Task {
            do {
                try await hermes.ask(text)
            } catch let error as GatewayError {
                errorText = error.message
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Spawn task sheet

private struct SpawnTaskSheet: View {
    @EnvironmentObject private var hermes: HermesService
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var repo = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What should hermes do?", text: $prompt, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Repository (optional)") {
                    TextField("owner/repo or path", text: $repo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let errorText {
                    Text(errorText).foregroundStyle(Theme.Palette.live)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Starting…" : "Start") { start() }
                        .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func start() {
        busy = true
        errorText = nil
        Task {
            do {
                _ = try await hermes.spawnTask(
                    prompt: prompt,
                    repo: repo.isEmpty ? nil : repo,
                    label: nil)
                dismiss()
            } catch let error as GatewayError {
                errorText = error.message
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }
}

// MARK: - Channel message sheet

private struct ChannelMessageSheet: View {
    @EnvironmentObject private var hermes: HermesService
    @Environment(\.dismiss) private var dismiss
    @State private var channel = "telegram"
    @State private var recipient = ""
    @State private var text = ""
    @State private var busy = false
    @State private var errorText: String?

    private let channels = ["telegram", "whatsapp", "discord", "slack"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Channel") {
                    Picker("Channel", selection: $channel) {
                        ForEach(channels, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    TextField("Recipient (chat id, phone, @user)", text: $recipient)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Message") {
                    TextField("Message", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let errorText {
                    Text(errorText).foregroundStyle(Theme.Palette.live)
                }
            }
            .navigationTitle("Send Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Sending…" : "Send") { send() }
                        .disabled(recipient.isEmpty || text.isEmpty || busy)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func send() {
        busy = true
        errorText = nil
        Task {
            do {
                try await hermes.sendChannelMessage(channel: channel, to: recipient, text: text)
                dismiss()
            } catch let error as GatewayError {
                errorText = error.message
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }
}
