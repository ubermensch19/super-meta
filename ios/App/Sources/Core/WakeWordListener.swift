import Foundation
import SwiftUI
import Speech
import AVFoundation
import AudioToolbox

/// Always-on wake-phrase listener. Runs an on-device `SFSpeechRecognizer` over a
/// dedicated `AVAudioEngine` tap so a user-chosen phrase ("hey neo", "hey vision"…)
/// can start Live AI hands-free — heard through the glasses' Bluetooth HFP mic when
/// they're connected, otherwise the phone mic, and while the app is backgrounded /
/// the phone is locked (the active audio session keeps the app alive).
///
/// The robustness here — restart throttling, format guards, defensive tap removal,
/// reviving the engine in place on route changes, and route/interruption observers —
/// is what keeps recognition alive across the flaky 8 kHz HFP link and long
/// background runs. It mirrors the hard-won handling in the OpenVision reference app.
@MainActor
final class WakeWordListener: ObservableObject {
    static let shared = WakeWordListener()

    /// Master switch. Persisted; enabling starts listening, disabling tears down.
    @Published var enabled: Bool {
        didSet {
            guard oldValue != enabled else { return }
            defaults.set(enabled, forKey: Keys.enabled)
            if enabled { start() } else { stop() }
        }
    }

    /// The phrase to listen for. Matched case-insensitively as a substring of
    /// partial transcripts; empty is ignored (kept as the last non-empty value).
    @Published var phrase: String {
        didSet {
            let trimmed = phrase.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            defaults.set(trimmed, forKey: Keys.phrase)
            // Rebias the recognizer for the new phrase.
            if listening { scheduleRestart() }
        }
    }

    /// Invoked on the main actor when the wake phrase is detected. Set by the app.
    var onWake: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// True while the user wants us listening (toggle on and not paused).
    private var listening = false
    /// True while a realtime session is holding the mic; we suspend then.
    private var paused = false
    /// Guards against restart storms — recognizers can die and re-fire instantly.
    private var lastRestart = Date.distantPast
    /// Cooldown so one utterance doesn't fire the wake handler repeatedly.
    private var lastWake = Date.distantPast
    private var restartScheduled = false
    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "wake_word_enabled"
        static let phrase = "wake_phrase"
    }

    private init() {
        self.enabled = defaults.bool(forKey: Keys.enabled)
        self.phrase = defaults.string(forKey: Keys.phrase) ?? "hey vision"
        // AVAudioSession posts these on a background thread, so deliver them through
        // a closure that hops to the main actor. A @MainActor @objc selector would
        // trip a libdispatch queue assertion and crash when a BT route change fires.
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.listening, !self.paused else { return }
                self.scheduleRestart()
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: nil
        ) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            Task { @MainActor in
                guard let self, self.listening, !self.paused else { return }
                switch type {
                case .began: self.teardownRecognition()
                case .ended: self.scheduleRestart()
                default: break
                }
            }
        }
    }

    // MARK: Lifecycle

    /// Begin listening if enabled. Requests speech authorization the first time.
    func start() {
        guard enabled, !listening else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self, self.enabled else { return }
                guard status == .authorized else {
                    // Permission denied — revert the toggle so Settings reflects reality.
                    self.enabled = false
                    return
                }
                self.listening = true
                self.paused = false
                self.beginRecognition()
            }
        }
    }

    /// Stop listening entirely (toggle off).
    func stop() {
        listening = false
        paused = false
        teardownRecognition()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Release the mic for a realtime session without forgetting we want to listen.
    func pause() {
        guard listening, !paused else { return }
        paused = true
        teardownRecognition()
    }

    /// Resume listening after a realtime session ends.
    func resume() {
        guard listening, paused else { return }
        paused = false
        scheduleRestart()
    }

    // MARK: Recognition

    private func beginRecognition() {
        guard listening, !paused else { return }
        guard let recognizer, recognizer.isAvailable else { scheduleRestart(); return }

        teardownRecognition()

        do {
            try configureAudioSession()
        } catch {
            scheduleRestart(); return
        }

        let input = audioEngine.inputNode
        let format = input.inputFormat(forBus: 0)
        // Mic held by a call, or route mid-renegotiation → invalid format. Retry later.
        guard format.sampleRate > 0, format.channelCount > 0 else { scheduleRestart(); return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        request.contextualStrings = contextualStrings()
        self.request = request

        input.removeTap(onBus: 0) // defensive — a stale tap makes install throw
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            scheduleRestart(); return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.evaluate(text)
                }
                if error != nil || (result?.isFinal ?? false) {
                    // Recognizers finalize after ~1 min (or instantly on flaky HFP);
                    // just start a fresh one.
                    if self.listening, !self.paused { self.scheduleRestart() }
                }
            }
        }
    }

    private func teardownRecognition() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        // Keep the SAME engine instance — rebuilding it goes deaf after an HFP
        // renegotiation. Just pull the tap.
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Throttled restart. Reviving the existing engine in place (rather than
    /// rebuilding) is what survives glasses connect/disconnect.
    private func scheduleRestart() {
        guard listening, !paused, !restartScheduled else { return }
        restartScheduled = true
        let elapsed = Date().timeIntervalSince(lastRestart)
        let delay = max(0, 0.6 - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.restartScheduled = false
            guard self.listening, !self.paused else { return }
            self.lastRestart = Date()
            self.beginRecognition()
        }
    }

    private func evaluate(_ transcript: String) {
        let needle = phrase.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return }
        guard transcript.lowercased().contains(needle) else { return }
        // Cooldown so one long partial doesn't re-fire.
        guard Date().timeIntervalSince(lastWake) > 2 else { return }
        lastWake = Date()
        AudioServicesPlaySystemSound(1113) // short activation chime → glasses speakers
        onWake?()
    }

    // MARK: Audio session (glasses HFP mic)

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // `.mixWithOthers` + `.default` mode keeps the glasses camera stream from
        // killing the HFP mic; `.defaultToSpeaker` sends the chime out loud.
        try session.setCategory(
            .playAndRecord, mode: .default,
            options: [.mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker])
        try session.setActive(true, options: [])
        // Prefer the glasses' HFP mic when present; else the phone mic.
        if let hfp = session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
            try? session.setPreferredInput(hfp)
        } else {
            try? session.setPreferredInput(nil)
        }
    }

    /// The phrase plus a few spacing/homophone variants — biasing is the single
    /// biggest reliability lever over the glasses' low-bitrate HFP mic.
    private func contextualStrings() -> [String] {
        let base = phrase.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return [] }
        var out: Set<String> = [base, base.lowercased()]
        let words = base.split(separator: " ")
        if words.count >= 2 {
            out.insert(words.joined(separator: ", "))
            if let last = words.last { out.insert(String(last)) }
        }
        return Array(out)
    }

}
