#if os(iOS)
import Foundation
import AVFoundation
import os.log

private let log = Logger(subsystem: "com.priyanshu.metamod", category: "RealtimeAudio")

/// Captures microphone audio as PCM16 @ 24 kHz mono (for the Realtime API) and
/// plays back PCM16 @ 24 kHz audio deltas from the model. iOS only.
///
/// Note: this audio path is build-validated; the live websocket/protocol layer is
/// covered by tests, but mic capture + playback require on-device verification.
public final class RealtimeAudioEngine: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    /// Mic PCM16 wire format. Sample rate is chosen per provider in `start`
    /// (24 kHz for OpenAI, 16 kHz for Gemini Live).
    private var wireFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24_000, channels: 1, interleaved: true)!
    /// Float32 @ 24 kHz for the player node (both providers emit 24 kHz audio).
    private let playFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!

    private var onMicChunk: (@Sendable (Data) -> Void)?
    private var captureConverter: AVAudioConverter?
    private var playerAttached = false

    public init() {}

    public func start(captureSampleRate: Double = 24_000, onMicChunk: @escaping @Sendable (Data) -> Void) throws {
        self.onMicChunk = onMicChunk
        wireFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: captureSampleRate, channels: 1, interleaved: true)!

        let session = AVAudioSession.sharedInstance()
        // Match the OpenGlasses profile: voiceChat restricts routes and can fight
        // the glasses camera/HFP session. The default mixed profile preserves the
        // Meta/Ray-Ban input while Gemini owns the mic.
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try session.setActive(true)
        let glassesTypes: Set<AVAudioSession.Port> = [.bluetoothHFP, .bluetoothLE, .headsetMic]
        if let glasses = session.availableInputs?.first(where: { input in
            glassesTypes.contains(input.portType)
                && ["meta", "ray-ban", "rayban"].contains { input.portName.lowercased().contains($0) }
        }) ?? session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
            try? session.setPreferredInput(glasses)
        }

        if !playerAttached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: playFormat)
            playerAttached = true
        }

        let input = engine.inputNode
        // Match the active microphone hardware (16 kHz on glasses HFP). Using the
        // input node's 48 kHz output format causes the -10868 format mismatch seen
        // on-device before either wake recognition or Gemini Live can receive audio.
        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw NSError(domain: "RealtimeAudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone input is unavailable"])
        }
        captureConverter = AVAudioConverter(from: inputFormat, to: wireFormat)

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.handleMic(buffer)
        }

        engine.prepare()
        try engine.start()
        player.play()
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Playback

    /// Enqueue a PCM16 @ 24 kHz audio delta from the model for playback.
    public func enqueue(pcm16 data: Data) {
        guard let buffer = Self.pcm16ToFloatBuffer(data, format: playFormat) else { return }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // MARK: Capture

    private func handleMic(_ buffer: AVAudioPCMBuffer) {
        guard let converter = captureConverter,
              let out = AVAudioPCMBuffer(pcmFormat: wireFormat, frameCapacity: 4096) else { return }
        var error: NSError?
        var fed = false
        let status = converter.convert(to: out, error: &error) { _, inStatus in
            if fed { inStatus.pointee = .noDataNow; return nil }
            fed = true
            inStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, out.frameLength > 0,
              let channelData = out.int16ChannelData else { return }
        let byteCount = Int(out.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData[0], count: byteCount)
        onMicChunk?(data)
    }

    static func pcm16ToFloatBuffer(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)),
              let floatChannel = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                floatChannel[0][i] = Float(samples[i]) / Float(Int16.max)
            }
        }
        return buffer
    }
}
#endif
