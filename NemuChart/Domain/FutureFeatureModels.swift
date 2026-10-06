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

struct AlarmSoundSummary: Identifiable, Equatable, Sendable {
    var id: String { sound.rawValue }
    let sound: AlarmSoundChoice
    let stoppedCount: Int
    let averageSnoozeCount: Double
    let averageMinutesToStop: Double
}

enum AlarmResultLog {
    static let maximumCount = 120

    static func scheduled(_ result: AlarmResult, in results: [AlarmResult]) -> [AlarmResult] {
        Array((results.filter { $0.id != result.id } + [result]).suffix(maximumCount))
    }

    static func snoozed(id: UUID, in results: [AlarmResult]) -> [AlarmResult] {
        results.map { result in
            guard result.id == id, result.stoppedAt == nil else { return result }
            var updated = result
            updated.snoozeCount += 1
            return updated
        }
    }

    static func stopped(id: UUID, at date: Date, in results: [AlarmResult]) -> [AlarmResult] {
        results.map { result in
            guard result.id == id, result.stoppedAt == nil else { return result }
            var updated = result
            updated.stoppedAt = max(date, result.scheduledAt)
            return updated
        }
    }

    /// 鳴る前に取り消した予約だけを除く。鳴った後の結果は残す。
    static func cancelled(id: UUID, now: Date, in results: [AlarmResult]) -> [AlarmResult] {
        results.filter { !($0.id == id && $0.stoppedAt == nil && $0.snoozeCount == 0 && $0.scheduledAt > now) }
    }

    static func summaries(_ results: [AlarmResult]) -> [AlarmSoundSummary] {
        AlarmSoundChoice.allCases.compactMap { sound in
            let stopped = results.filter { $0.sound == sound && $0.stoppedAt != nil }
            guard !stopped.isEmpty else { return nil }
            let count = Double(stopped.count)
            let snoozes = stopped.reduce(0) { $0 + $1.snoozeCount }
            let minutes = stopped.reduce(0.0) { $0 + $1.stoppedAt!.timeIntervalSince($1.scheduledAt) / 60 }
            return AlarmSoundSummary(
                sound: sound,
                stoppedCount: stopped.count,
                averageSnoozeCount: Double(snoozes) / count,
                averageMinutesToStop: minutes / count
            )
        }
    }
}
