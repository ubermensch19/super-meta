import Foundation

/// A live-streaming destination with a known RTMP ingest URL. Picking one fills in
/// the URL field; the user still pastes their own stream key. `custom` leaves the
/// URL blank for self-hosted / other endpoints.
enum StreamingPlatform: String, CaseIterable, Identifiable {
    case custom, youtube, twitch, facebook, kick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .custom: return "Custom"
        case .youtube: return "YouTube"
        case .twitch: return "Twitch"
        case .facebook: return "Facebook"
        case .kick: return "Kick"
        }
    }

    /// The platform's RTMP ingest endpoint (without the stream key). Empty for `custom`.
    var defaultURL: String {
        switch self {
        case .custom: return ""
        case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
        case .twitch: return "rtmp://live.twitch.tv/app"
        case .facebook: return "rtmps://live-api-s.facebook.com:443/rtmp"
        case .kick: return "rtmps://fa723fc1b171.global-contribute.live-video.net/app"
        }
    }

    var icon: String {
        switch self {
        case .custom: return "server.rack"
        case .youtube: return "play.rectangle.fill"
        case .twitch: return "gamecontroller.fill"
        case .facebook: return "f.circle.fill"
        case .kick: return "bolt.fill"
        }
    }

    /// Best-effort match of a saved URL back to a known platform, so the preset row
    /// reflects the persisted URL on relaunch.
    static func matching(url: String) -> StreamingPlatform {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .custom }
        return allCases.first { $0 != .custom && $0.defaultURL == trimmed } ?? .custom
    }
}
