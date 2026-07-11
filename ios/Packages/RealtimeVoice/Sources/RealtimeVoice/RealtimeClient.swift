import Foundation

/// A realtime voice client the app can drive uniformly, regardless of provider
/// (OpenAI Realtime or Gemini Live). `RealtimeSession` holds `any RealtimeClient`.
public protocol RealtimeClient: AnyObject, Sendable {
    /// Normalized event stream (audio deltas, transcripts, tool calls, errors).
    var events: AsyncStream<RealtimeEvent> { get }

    func connect()
    func disconnect()

    /// Append a chunk of mic PCM16 audio. The sample rate must match what the
    /// provider expects (24 kHz for OpenAI, 16 kHz for Gemini).
    func appendAudio(_ pcm16: Data)

    /// Send a text turn and request a spoken response.
    func sendText(_ text: String)

    /// Attach an image frame (JPEG) as visual context.
    func sendImage(_ jpeg: Data, note: String)

    /// Return a tool/function result to the model.
    func sendFunctionOutput(callID: String, output: String)

    /// Ask the model to produce a response now (e.g. after a tool result).
    func createResponse()
}
