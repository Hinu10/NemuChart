import Foundation
import SwiftData

@Model
final class SleepRecordEntity {
    @Attribute(.unique) var id: UUID
    var sleepDayKey: String
    var sleepDayYear: Int
    var sleepDayMonth: Int
    var sleepDayDay: Int
    var timeZoneIdentifier: String
    var bedTime: Date
    var sleepStart: Date
    var wakeTime: Date
    var freshnessRawValue: Int
    var factorsData: Data
    var createdAt: Date
    var updatedAt: Date

    init(record: SleepRecord) throws {
        id = record.id
        sleepDayKey = record.sleepDay.key
        sleepDayYear = record.sleepDay.year
        sleepDayMonth = record.sleepDay.month
        sleepDayDay = record.sleepDay.day
        timeZoneIdentifier = record.sleepDay.timeZoneIdentifier
        bedTime = record.bedTime
        sleepStart = record.sleepStart
        wakeTime = record.wakeTime
        freshnessRawValue = record.freshness.rawValue
        factorsData = try JSONEncoder().encode(record.factors)
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func update(from record: SleepRecord, at updateTime: Date) throws {
        sleepDayKey = record.sleepDay.key
        sleepDayYear = record.sleepDay.year
        sleepDayMonth = record.sleepDay.month
        sleepDayDay = record.sleepDay.day
        timeZoneIdentifier = record.sleepDay.timeZoneIdentifier
        bedTime = record.bedTime
        sleepStart = record.sleepStart
        wakeTime = record.wakeTime
        freshnessRawValue = record.freshness.rawValue
        factorsData = try JSONEncoder().encode(record.factors)
        updatedAt = max(updateTime, createdAt)
    }

    func domainModel() throws -> SleepRecord {
        guard let freshness = Freshness(rawValue: freshnessRawValue) else {
            throw RepositoryError.invalidStoredData("スッキリ度が範囲外です")
        }
        do {
            let day = try SleepDay(
                year: sleepDayYear,
                month: sleepDayMonth,
                day: sleepDayDay,
                timeZoneIdentifier: timeZoneIdentifier
            )
            return try SleepRecord(
                id: id,
                sleepDay: day,
                bedTime: bedTime,
                sleepStart: sleepStart,
                wakeTime: wakeTime,
                freshness: freshness,
                factors: try JSONDecoder().decode(SleepFactors.self, from: factorsData),
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.invalidStoredData(error.localizedDescription)
        }
    }
}

@Model
final class UserSettingsEntity {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var desiredSleepDuration: TimeInterval
    var sleepDurationPreferenceRawValue: String = SleepDurationPreference.known.rawValue
    var standardWakeHour: Int
    var standardWakeMinute: Int
    var averageSleepLatencyMinutes: Int?
    var weekStartRawValue: Int
    var notificationsEnabledInApp: Bool
    var notificationAuthorizationRawValue: String
    var updatedAt: Date

    init(settings: UserSettings) {
        id = settings.id
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        desiredSleepDuration = settings.desiredSleepDuration
        sleepDurationPreferenceRawValue = settings.sleepDurationPreference.rawValue
        standardWakeHour = settings.standardWakeTime.hour
        standardWakeMinute = settings.standardWakeTime.minute
        averageSleepLatencyMinutes = settings.averageSleepLatencyMinutes
        weekStartRawValue = settings.weekStart.rawValue
        notificationsEnabledInApp = settings.notificationPreference.isEnabledInApp
        notificationAuthorizationRawValue = settings.notificationPreference.authorizationState.rawValue
        updatedAt = settings.updatedAt
    }

    func update(from settings: UserSettings) {
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        desiredSleepDuration = settings.desiredSleepDuration
        sleepDurationPreferenceRawValue = settings.sleepDurationPreference.rawValue
        standardWakeHour = settings.standardWakeTime.hour
        standardWakeMinute = settings.standardWakeTime.minute
        averageSleepLatencyMinutes = settings.averageSleepLatencyMinutes
        weekStartRawValue = settings.weekStart.rawValue
        notificationsEnabledInApp = settings.notificationPreference.isEnabledInApp
        notificationAuthorizationRawValue = settings.notificationPreference.authorizationState.rawValue
        updatedAt = settings.updatedAt
    }

    func domainModel() throws -> UserSettings {
        guard let wakeTime = LocalTime(hour: standardWakeHour, minute: standardWakeMinute),
              let weekStart = WeekStart(rawValue: weekStartRawValue),
              let sleepDurationPreference = SleepDurationPreference(rawValue: sleepDurationPreferenceRawValue),
              let authorization = NotificationAuthorizationState(
                rawValue: notificationAuthorizationRawValue
              ) else {
            throw RepositoryError.invalidStoredData("設定値が範囲外です")
        }
        do {
            return try UserSettings(
                id: id,
                hasCompletedOnboarding: hasCompletedOnboarding,
                desiredSleepDuration: desiredSleepDuration,
                sleepDurationPreference: sleepDurationPreference,
                standardWakeTime: wakeTime,
                averageSleepLatencyMinutes: averageSleepLatencyMinutes,
                weekStart: weekStart,
                notificationPreference: NotificationPreference(
                    isEnabledInApp: notificationsEnabledInApp,
                    authorizationState: authorization
                ),
                updatedAt: updatedAt
            )
        } catch {
            throw RepositoryError.invalidStoredData(error.localizedDescription)
        }
    }
}

@Model
final class SleepGoalEntity {
    @Attribute(.unique) var id: UUID
    var targetBedHour: Int
    var targetBedMinute: Int
    var targetSleepHour: Int
    var targetSleepMinute: Int
    var targetWakeHour: Int
    var targetWakeMinute: Int
    var timeZoneIdentifier: String
    var createdAt: Date
    var updatedAt: Date

    init(goal: SleepGoal) {
        id = goal.id
        targetBedHour = goal.targetBedTime.hour
        targetBedMinute = goal.targetBedTime.minute
        targetSleepHour = goal.targetSleepTime.hour
        targetSleepMinute = goal.targetSleepTime.minute
        targetWakeHour = goal.targetWakeTime.hour
        targetWakeMinute = goal.targetWakeTime.minute
        timeZoneIdentifier = goal.timeZoneIdentifier
        createdAt = goal.createdAt
        updatedAt = goal.updatedAt
    }

    func update(from goal: SleepGoal) {
        targetBedHour = goal.targetBedTime.hour
        targetBedMinute = goal.targetBedTime.minute
        targetSleepHour = goal.targetSleepTime.hour
        targetSleepMinute = goal.targetSleepTime.minute
        targetWakeHour = goal.targetWakeTime.hour
        targetWakeMinute = goal.targetWakeTime.minute
        timeZoneIdentifier = goal.timeZoneIdentifier
        updatedAt = goal.updatedAt
    }

    func domainModel() throws -> SleepGoal {
        guard let bed = LocalTime(hour: targetBedHour, minute: targetBedMinute),
              let sleep = LocalTime(hour: targetSleepHour, minute: targetSleepMinute),
              let wake = LocalTime(hour: targetWakeHour, minute: targetWakeMinute) else {
            throw RepositoryError.invalidStoredData("目標時刻が範囲外です")
        }
        do {
            return try SleepGoal(
                id: id,
                targetBedTime: bed,
                targetSleepTime: sleep,
                targetWakeTime: wake,
                timeZoneIdentifier: timeZoneIdentifier,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        } catch {
            throw RepositoryError.invalidStoredData(error.localizedDescription)
        }
    }
}
