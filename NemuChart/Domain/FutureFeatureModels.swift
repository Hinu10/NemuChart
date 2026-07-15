import Foundation

enum AlarmSoundChoice: String, Codable, CaseIterable, Sendable {
    case system
    case gentleChime
    case birds

    var displayName: String {
        switch self {
        case .system: String(localized: "システム標準")
        case .gentleChime: String(localized: "やさしいチャイム")
        case .birds: String(localized: "小鳥")
        }
    }
}

enum AlarmDeliveryMode: String, Codable, Sendable {
    case alarmKit
    case notificationFallback
}

struct AlarmResult: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let scheduledAt: Date
    let sound: AlarmSoundChoice
    var snoozeCount: Int
    var stoppedAt: Date?
    let deliveryMode: AlarmDeliveryMode

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        sound: AlarmSoundChoice,
        snoozeCount: Int = 0,
        stoppedAt: Date? = nil,
        deliveryMode: AlarmDeliveryMode
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.sound = sound
        self.snoozeCount = max(0, snoozeCount)
        self.stoppedAt = stoppedAt
        self.deliveryMode = deliveryMode
    }
}

enum LifestyleFactorKind: String, CaseIterable, Sendable {
    case alcohol
    case caffeine
    case nap
    case smartphone

    var displayName: String {
        switch self {
        case .alcohol: String(localized: "飲酒")
        case .caffeine: String(localized: "カフェイン")
        case .nap: String(localized: "昼寝")
        case .smartphone: String(localized: "就寝30分前までにスマホを終了")
        }
    }
}

struct FactorAssociationResult: Identifiable, Equatable, Sendable {
    var id: String { factor.rawValue }
    let factor: LifestyleFactorKind
    let exposedCount: Int
    let comparisonCount: Int
    let freshnessDifference: Double
    let confidence: AnalysisConfidence
}

struct LongTermBucket: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let recordCount: Int
    let averageDuration: TimeInterval
    let averageFreshness: Double
}

struct LongTermReport: Equatable, Sendable {
    let requestedDays: Int
    let recordCount: Int
    let monthly: [LongTermBucket]
    let weekdays: [LongTermBucket]
    let weekdayFreshness: Double?
    let weekendFreshness: Double?
    let timeZoneCount: Int
}
