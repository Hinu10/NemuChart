import Foundation

enum NotificationAuthorizationState: String, Codable, CaseIterable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

struct NotificationPreference: Codable, Equatable, Sendable {
    var isEnabledInApp: Bool
    var authorizationState: NotificationAuthorizationState
}

enum SleepDurationPreference: String, Codable, CaseIterable, Sendable {
    case known
    case inferred
}

struct UserSettings: Identifiable, Codable, Equatable, Sendable {
    static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let id: UUID
    var hasCompletedOnboarding: Bool
    var desiredSleepDuration: TimeInterval
    var sleepDurationPreference: SleepDurationPreference
    var standardWakeTime: LocalTime
    var averageSleepLatencyMinutes: Int?
    var weekStart: WeekStart
    var notificationPreference: NotificationPreference
    var updatedAt: Date

    init(
        id: UUID = UserSettings.singletonID,
        hasCompletedOnboarding: Bool = false,
        desiredSleepDuration: TimeInterval,
        sleepDurationPreference: SleepDurationPreference = .known,
        standardWakeTime: LocalTime,
        averageSleepLatencyMinutes: Int? = nil,
        weekStart: WeekStart = .monday,
        notificationPreference: NotificationPreference = .init(
            isEnabledInApp: false,
            authorizationState: .notDetermined
        ),
        updatedAt: Date = Date()
    ) throws {
        guard (3 * 60 * 60...16 * 60 * 60).contains(desiredSleepDuration) else {
            throw UserSettingsValidationError.invalidDesiredSleepDuration
        }
        guard averageSleepLatencyMinutes.map({ (0...240).contains($0) }) ?? true else {
            throw UserSettingsValidationError.invalidSleepLatency
        }

        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.desiredSleepDuration = desiredSleepDuration
        self.sleepDurationPreference = sleepDurationPreference
        self.standardWakeTime = standardWakeTime
        self.averageSleepLatencyMinutes = averageSleepLatencyMinutes
        self.weekStart = weekStart
        self.notificationPreference = notificationPreference
        self.updatedAt = updatedAt
    }
}

struct SleepGoal: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var targetBedTime: LocalTime
    var targetSleepTime: LocalTime
    var targetWakeTime: LocalTime
    var timeZoneIdentifier: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        targetBedTime: LocalTime,
        targetSleepTime: LocalTime,
        targetWakeTime: LocalTime,
        timeZoneIdentifier: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw DateTimeError.invalidTimeZone(timeZoneIdentifier)
        }
        guard createdAt <= updatedAt else { throw UserSettingsValidationError.invalidTimestamps }
        self.id = id
        self.targetBedTime = targetBedTime
        self.targetSleepTime = targetSleepTime
        self.targetWakeTime = targetWakeTime
        self.timeZoneIdentifier = timeZoneIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum UserSettingsValidationError: Error, Equatable {
    case invalidDesiredSleepDuration
    case invalidSleepLatency
    case invalidTimestamps
}
