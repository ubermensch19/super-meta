import Foundation
import RealtimeVoice

/// Realtime tool definitions that let the voice model command the user's
/// OpenClaw/Hermes agent. Dispatched by `HermesService.handleToolCall`.
enum HermesTools {
    /// A single rich delegate keeps Gemini's side simple: Hermes receives the
    /// complete natural-language intent and selects the appropriate configured
    /// capability (Composio, MCP, browser, messaging, calendar, and so on).
    static let all: [RealtimeTool] = [execute, ask, spawnTask, sendMessage, sessionsStatus]

    /// Appended to the session instructions when hermes is paired.
    static let instructionsAddendum = """
     You can also command the user's personal AI agent, called hermes, through tools: \
    hermes_execute for any real-world action or request, hermes_ask for questions, hermes_spawn_task to start a background job \
    like a coding task, hermes_send_message to message people through the agent's \
    channels, and hermes_sessions_status to check what it is working on. Confirm the \
    recipient and content out loud before sending any message. If a tool reports that \
    hermes is still working, tell the user you'll announce the answer when it's ready.
    """

    static let execute = RealtimeTool(
        name: "hermes_execute",
        description: "Delegate a complete user request to Hermes so it can use the user's connected tools and services. Use for actions, research, calendars, messaging, Composio integrations, browser work, or any task that must be done outside this conversation.",
        parametersJSON: """
        {"type":"object","properties":{\
        "task":{"type":"string","description":"Complete, specific description of what Hermes should do"}},\
        "required":["task"]}
        """
    )

    /// Used when a saved endpoint exists but is not currently reachable from
    /// the phone. This prevents the model from promising an action it has no
    /// live tool for, while leaving native Gemini features (including Search)
    /// fully available.
    static let unavailableInstructions = """
    Hermes is currently offline or not paired with this phone. Do not claim you
    can send work to Hermes, access its connected services, or wait for a
    Hermes reply. Explain briefly that the Hermes connection must be restored
    in the app before those actions are available.
    """

    static let ask = RealtimeTool(
        name: "hermes_ask",
        description: "Ask the user's personal agent (hermes) a question or give it an instruction, and get its reply. Use for anything the agent should answer or do conversationally.",
        parametersJSON: """
        {"type":"object","properties":{\
        "question":{"type":"string","description":"The question or instruction for hermes"},\
        "session_id":{"type":"string","description":"Optional session key to target; omit for the main session"}},\
        "required":["question"]}
        """
    )

    static let spawnTask = RealtimeTool(
        name: "hermes_spawn_task",
        description: "Start a new background task on the user's agent, such as a coding job on a repository. Returns the session it runs in.",
        parametersJSON: """
        {"type":"object","properties":{\
        "prompt":{"type":"string","description":"What the task should accomplish"},\
        "repo":{"type":"string","description":"Optional repository name or path the task concerns"}},\
        "required":["prompt"]}
        """
    )

    static let sendMessage = RealtimeTool(
        name: "hermes_send_message",
        description: "Send a message to someone through one of the agent's channels (telegram, whatsapp, discord, slack). Confirm recipient and content with the user first.",
        parametersJSON: """
        {"type":"object","properties":{\
        "channel":{"type":"string","enum":["telegram","whatsapp","discord","slack"]},\
        "recipient":{"type":"string","description":"Chat id, phone number, or @username"},\
        "message":{"type":"string"}},\
        "required":["channel","recipient","message"]}
        """
    )

    static let sessionsStatus = RealtimeTool(
        name: "hermes_sessions_status",
        description: "List the agent's sessions and what each is doing — use when the user asks what hermes is working on or a task's status.",
        parametersJSON: #"{"type":"object","properties":{}}"#
    )
}
