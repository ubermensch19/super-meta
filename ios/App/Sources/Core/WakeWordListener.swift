import Foundation
import SwiftUI
import Speech
import AVFoundation
import AudioToolbox

/// Owns the `AVAudioEngine` + `SFSpeechRecognizer` and runs every blocking audio
/// call (`AVAudioSession.setActive`, `AVAudioEngine.start`, Bluetooth HFP route
/// negotiation) on a private serial queue, so it never stalls the main thread.
/// Not main-actor isolated. Detection/lifecycle callbacks fire on the audio thread;
/// the owner hops them to the main actor.
private final class WakeAudioEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.priyanshu.metamod.wakeword.audio")
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Partial transcript text; fires on the recognition thread.
    var onPartial: (@Sendable (String) -> Void)?
    /// Recognizer finalized or errored, or setup failed → owner should restart.
    var onEnd: (@Sendable () -> Void)?

    /// (Re)start recognition. Non-blocking: all work happens on the serial queue.
    func start(contextualStrings: [String]) {
        queue.async { [weak self] in self?._start(contextualStrings) }
    }

    /// Tear down recognition; optionally deactivate the shared audio session.
    func stop(deactivate: Bool = false) {
        queue.async { [weak self] in self?._stop(deactivate: deactivate) }
    }

    private func _start(_ contextual: [String]) {
        NSLog("[WakeWord] _start begin (queue)")
        _stop(deactivate: false)
        guard let recognizer, recognizer.isAvailable else { NSLog("[WakeWord] recognizer unavailable"); onEnd?(); return }
        NSLog("[WakeWord] configuring session…")
        do { try configureSession() } catch { NSLog("[WakeWord] configureSession threw: \(error)"); onEnd?(); return }
        NSLog("[WakeWord] session configured")

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        NSLog("[WakeWord] input format \(format.sampleRate)Hz \(format.channelCount)ch")
        // Mic held by a call, or route mid-renegotiation → invalid format. Retry later.
        guard format.sampleRate > 0, format.channelCount > 0 else { onEnd?(); return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .search
        req.contextualStrings = contextual
        // On-device wake spotting (matches OpenGlasses): avoids streaming mic audio to
        // Apple's servers 24/7 and removes the network round-trip from detection.
        req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request = req

        input.removeTap(onBus: 0) // defensive — a stale tap makes install throw
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
            req?.append(buffer)
        }

        engine.prepare()
        NSLog("[WakeWord] engine.prepare done, starting…")
        do {
            try engine.start()
        } catch {
            NSLog("[WakeWord] engine.start threw: \(error)")
            input.removeTap(onBus: 0)
            onEnd?(); return
        }
        NSLog("[WakeWord] engine started, creating recognitionTask")

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            if let result { self?.onPartial?(result.bestTranscription.formattedString) }
            if error != nil || (result?.isFinal ?? false) { self?.onEnd?() }
        }
    }

    private func _stop(deactivate: Bool) {
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if engine.isRunning { engine.stop() }
        // Keep the SAME engine instance — rebuilding it goes deaf after an HFP
        // renegotiation. Just pull the tap.
        engine.inputNode.removeTap(onBus: 0)
        if deactivate {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func configureSession() throws {
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
}

/// Always-on wake-phrase listener. Runs an on-device `SFSpeechRecognizer` over a
/// dedicated `AVAudioEngine` tap so a user-chosen phrase ("hey neo", "hey vision"…)
/// can start Live AI hands-free — heard through the glasses' Bluetooth HFP mic when
/// they're connected, otherwise the phone mic, and while the app is backgrounded /
/// the phone is locked (the active audio session keeps the app alive).
///
/// This object stays on the main actor for its published state and restart timing;
/// the actual audio work lives in `WakeAudioEngine` on a background queue so enabling
/// the toggle never freezes the UI. Restart throttling, route/interruption observers,
/// and recognizer-restart handling keep recognition alive across the flaky HFP link.
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

    private let audio = WakeAudioEngine()

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

        audio.onPartial = { [weak self] text in
            Task { @MainActor in self?.evaluate(text) }
        }
        audio.onEnd = { [weak self] in
            Task { @MainActor in
                guard let self, self.listening, !self.paused else { return }
                self.scheduleRestart()
            }
        }

        // AVAudioSession posts these on a background thread. Deliver on the main
        // queue so the main-actor closure body runs on the main actor — otherwise
        // Swift's isolation check (swift_task_isCurrentExecutor) traps and kills the
        // app when a Bluetooth route change fires on a real device.
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.listening, !self.paused else { return }
                self.scheduleRestart()
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated {
                guard let self, self.listening, !self.paused else { return }
                switch type {
                case .began: self.audio.stop()
                case .ended: self.scheduleRestart()
                default: break
                }
            }
        }
    }

    // MARK: Lifecycle

    /// Begin listening if enabled. Requests microphone AND speech permission first
    /// (both up front, like OpenGlasses) so starting the audio engine never stalls
    /// waiting on a permission prompt.
    func start() {
        guard enabled, !listening else { return }
        NSLog("[WakeWord] start() — requesting permissions")
        Task { @MainActor in
            let mic = await AVAudioApplication.requestRecordPermission()
            NSLog("[WakeWord] mic permission = \(mic)")
            let speech = await Self.requestSpeechAuthorization()
            NSLog("[WakeWord] speech permission = \(speech)")
            guard self.enabled else { return }
            guard mic, speech else {
                // Permission denied — revert the toggle so Settings reflects reality.
                self.enabled = false
                return
            }
            self.listening = true
            self.paused = false
            NSLog("[WakeWord] beginRecognition")
            self.beginRecognition()
        }
    }

    // `nonisolated`: SFSpeechRecognizer.requestAuthorization invokes its handler on a
    // background queue. If this stayed main-actor-isolated (the default for a static
    // member of a @MainActor type), Swift 6's runtime executor check would trap when
    // TCC calls the closure off-main. nonisolated lets the continuation resume from
    // any thread; the awaiting @MainActor caller still resumes on the main actor.
    nonisolated private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    /// Stop listening entirely (toggle off).
    func stop() {
        listening = false
        paused = false
        audio.stop(deactivate: true)
    }

    /// Release the mic for a realtime session without forgetting we want to listen.
    func pause() {
        guard listening, !paused else { return }
        paused = true
        audio.stop()
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
        // Non-blocking: the audio engine does its work on its own queue.
        audio.start(contextualStrings: contextualStrings())
    }

    /// Throttled restart. The audio engine revives in place (rather than rebuilding),
    /// which is what survives glasses connect/disconnect.
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
