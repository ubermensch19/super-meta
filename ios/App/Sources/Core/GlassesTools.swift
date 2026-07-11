import Foundation
import RealtimeVoice

/// Camera actions Gemini Live may request while talking to the wearer.
/// These are deliberately narrow: Gemini can inspect/capture the glasses view,
/// but cannot access unrelated photos or device data.
enum GlassesTools {
    static let all: [RealtimeTool] = [look, takePhoto, startCamera, stopCamera]

    static let instructionsAddendum = """
    You can inspect the wearer's real glasses view. For questions such as "what is in front of me?",
    "what do you see?", or "read this", call glasses_look first, then answer only from the image.
    Call glasses_take_photo when the wearer explicitly asks to take a photo. Use glasses_start_camera
    and glasses_stop_camera only when the wearer explicitly asks to start or stop the live camera.
    """

    static let look = RealtimeTool(
        name: "glasses_look",
        description: "Capture a fresh image from the wearer's glasses and inspect it before answering a visual question.",
        parametersJSON: #"{"type":"object","properties":{"question":{"type":"string","description":"What the wearer wants identified or described"}}}"#
    )

    static let takePhoto = RealtimeTool(
        name: "glasses_take_photo",
        description: "Take a fresh photo from the wearer's glasses when explicitly requested.",
        parametersJSON: #"{"type":"object","properties":{}}"#
    )

    static let startCamera = RealtimeTool(
        name: "glasses_start_camera",
        description: "Start the live glasses camera stream when explicitly requested.",
        parametersJSON: #"{"type":"object","properties":{}}"#
    )

    static let stopCamera = RealtimeTool(
        name: "glasses_stop_camera",
        description: "Stop the live glasses camera stream when explicitly requested.",
        parametersJSON: #"{"type":"object","properties":{}}"#
    )
}
