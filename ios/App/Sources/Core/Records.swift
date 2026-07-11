import Foundation
import SwiftData

/// A persisted result from any vision feature (Quick Vision, Vision Recognition, LeanEat).
@Model
final class VisionRecord {
    var id: UUID
    var kindRaw: String
    var prompt: String
    var result: String
    var thumbnail: Data?
    var createdAt: Date

    init(kind: VisionRecordKind, prompt: String, result: String, thumbnail: Data? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.prompt = prompt
        self.result = result
        self.thumbnail = thumbnail
        self.createdAt = createdAt
    }

    var kind: VisionRecordKind { VisionRecordKind(rawValue: kindRaw) ?? .quickVision }
}

enum VisionRecordKind: String, Codable, CaseIterable {
    case quickVision
    case visionRecognition
    case leanEat

    var title: String {
        switch self {
        case .quickVision: return "Quick Vision"
        case .visionRecognition: return "Vision"
        case .leanEat: return "LeanEat"
        }
    }
}
