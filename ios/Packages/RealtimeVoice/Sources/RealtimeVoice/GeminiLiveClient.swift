import Foundation
import os.log

private let log = Logger(subsystem: "com.priyanshu.metamod", category: "GeminiLive")

/// WebSocket client for the Gemini Live API (BidiGenerateContent). Same event
/// interface as `OpenAIRealtimeClient` so `RealtimeSession` can drive either.
///
/// Wire format: mic audio in as PCM16 @ 16 kHz, model audio out as PCM16 @ 24 kHz.
/// Auth: the API key is passed as the `?key=` query param (works for AIza… keys and
/// the newer AQ… AI Studio keys alike).
public final class GeminiLiveClient: RealtimeClient, @unchecked Sendable {
    private let apiKey: String
    private let config: RealtimeConfig
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    private var continuation: AsyncStream<RealtimeEvent>.Continuation?
    public let events: AsyncStream<RealtimeEvent>

    private static let geminiVoices: Set<String> = ["Aoede", "Charon", "Fenrir", "Kore", "Puck"]

    public init(apiKey: String, config: RealtimeConfig = .init(), session: URLSession = .shared) {
        self.apiKey = apiKey
        self.config = config
        self.session = session
        var cont: AsyncStream<RealtimeEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func connect() {
        let base = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        let encoded = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? apiKey
        guard let url = URL(string: "\(base)?key=\(encoded)") else {
            continuation?.yield(.error("Invalid Gemini Live URL")); return
        }
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop()
        sendSetup()
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        continuation?.finish()
    }

    // MARK: Outgoing

    private func sendSetup() {
        let voice = Self.geminiVoices.contains(config.voice) ? config.voice : "Aoede"
        var setup: [String: Any] = [
            "model": "models/\(config.model)",
            "generation_config": [
                "response_modalities": ["AUDIO"],
                "speech_config": ["voice_config": ["prebuilt_voice_config": ["voice_name": voice]]]
            ],
            "system_instruction": ["parts": [["text": config.instructions]]],
            // Enables the transcript stream the UI shows.
            "input_audio_transcription": [String: Any](),
            "output_audio_transcription": [String: Any]()
        ]
        if !config.tools.isEmpty {
            let decls = config.tools.map { tool -> [String: Any] in
                let params = (try? JSONSerialization.jsonObject(with: Data(tool.parametersJSON.utf8))) as? [String: Any] ?? [:]
                return ["name": tool.name, "description": tool.description, "parameters": params]
            }
            setup["tools"] = [["function_declarations": decls]]
        }
        send(["setup": setup])
    }

    public func appendAudio(_ pcm16: Data) {
        send(["realtime_input": ["media_chunks": [[
            "mime_type": "audio/pcm;rate=16000",
            "data": pcm16.base64EncodedString()
        ]]]])
    }

    public func sendImage(_ jpeg: Data, note: String = "") {
        send(["realtime_input": ["media_chunks": [[
            "mime_type": "image/jpeg",
            "data": jpeg.base64EncodedString()
        ]]]])
        if !note.isEmpty { sendText(note) }
    }

    public func sendText(_ text: String) {
        send(["client_content": [
            "turns": [["role": "user", "parts": [["text": text]]]],
            "turn_complete": true
        ]])
    }

    public func sendFunctionOutput(callID: String, output: String) {
        let responseObj = (try? JSONSerialization.jsonObject(with: Data(output.utf8))) as? [String: Any] ?? ["result": output]
        send(["tool_response": ["function_responses": [[
            "id": callID,
            "response": responseObj
        ]]]])
    }

    // Gemini auto-responds after a tool_response / client_content turn, so there's
    // no explicit "create response" call.
    public func createResponse() {}

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(string)) { error in
            if let error { log.error("gemini send failed: \(error.localizedDescription)") }
        }
    }

    // MARK: Incoming

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(message):
                self.handle(message)
                self.receiveLoop()
            case let .failure(error):
                self.continuation?.yield(.error(error.localizedDescription))
                self.continuation?.finish()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case let .string(s): data = Data(s.utf8)
        case let .data(d): data = d
        @unknown default: return
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if json["setupComplete"] != nil || json["setup_complete"] != nil {
            continuation?.yield(.sessionCreated)
            return
        }

        if let server = json["serverContent"] as? [String: Any] ?? json["server_content"] as? [String: Any] {
            handleServerContent(server)
            return
        }

        if let toolCall = json["toolCall"] as? [String: Any] ?? json["tool_call"] as? [String: Any] {
            let calls = toolCall["functionCalls"] as? [[String: Any]] ?? toolCall["function_calls"] as? [[String: Any]] ?? []
            for call in calls {
                let name = call["name"] as? String ?? ""
                let id = call["id"] as? String ?? name
                let args = call["args"] as? [String: Any] ?? [:]
                let argsJSON = (try? JSONSerialization.data(withJSONObject: args)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                continuation?.yield(.functionCall(name: name, callID: id, argumentsJSON: argsJSON))
            }
            return
        }

        if json["error"] != nil {
            let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "Gemini Live error"
            continuation?.yield(.error(msg))
        }
    }

    private func handleServerContent(_ content: [String: Any]) {
        if let modelTurn = content["modelTurn"] as? [String: Any] ?? content["model_turn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = part["inlineData"] as? [String: Any] ?? part["inline_data"] as? [String: Any],
                   let b64 = inline["data"] as? String, let audio = Data(base64Encoded: b64) {
                    continuation?.yield(.assistantAudioDelta(audio))
                }
                if let text = part["text"] as? String, !text.isEmpty {
                    continuation?.yield(.assistantTextDelta(text))
                }
            }
        }
        if let out = content["outputTranscription"] as? [String: Any] ?? content["output_transcription"] as? [String: Any],
           let text = out["text"] as? String, !text.isEmpty {
            continuation?.yield(.assistantTextDelta(text))
        }
        if let inp = content["inputTranscription"] as? [String: Any] ?? content["input_transcription"] as? [String: Any],
           let text = inp["text"] as? String, !text.isEmpty {
            continuation?.yield(.userTranscript(text))
        }
        if (content["turnComplete"] as? Bool ?? content["turn_complete"] as? Bool) == true {
            continuation?.yield(.responseDone)
        }
    }
}

private extension CharacterSet {
    /// Query-value safe set (excludes `&`, `=`, `+`, `?`, `/` etc. from the token).
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+?/")
        return set
    }()
}
