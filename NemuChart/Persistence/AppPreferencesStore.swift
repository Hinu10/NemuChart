import Foundation

struct AppPreferenceData: Codable, Equatable {
    var actionGoal: DailyActionGoal?
    var weeklyGoal: WeeklyGoal?
    var weeklyGoalFirstConfiguredAt: Date?
    var rewardedWeeklyGoalIDs: Set<UUID> = []
    var safetyGuidanceDismissedAt: Date?
    var alarmSound: AlarmSoundChoice = .system
    var alarmResults: [AlarmResult] = []

    private enum CodingKeys: String, CodingKey {
        case actionGoal, weeklyGoal, weeklyGoalFirstConfiguredAt, rewardedWeeklyGoalIDs, safetyGuidanceDismissedAt
        case alarmSound, alarmResults
    }

    init(
        actionGoal: DailyActionGoal? = nil,
        weeklyGoal: WeeklyGoal? = nil,
        weeklyGoalFirstConfiguredAt: Date? = nil,
        rewardedWeeklyGoalIDs: Set<UUID> = [],
        safetyGuidanceDismissedAt: Date? = nil,
        alarmSound: AlarmSoundChoice = .system,
        alarmResults: [AlarmResult] = []
    ) {
        self.actionGoal = actionGoal
        self.weeklyGoal = weeklyGoal
        self.weeklyGoalFirstConfiguredAt = weeklyGoalFirstConfiguredAt
        self.rewardedWeeklyGoalIDs = rewardedWeeklyGoalIDs
        self.safetyGuidanceDismissedAt = safetyGuidanceDismissedAt
        self.alarmSound = alarmSound
        self.alarmResults = alarmResults
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        actionGoal = try values.decodeIfPresent(DailyActionGoal.self, forKey: .actionGoal)
        weeklyGoal = try values.decodeIfPresent(WeeklyGoal.self, forKey: .weeklyGoal)
        weeklyGoalFirstConfiguredAt = try values.decodeIfPresent(Date.self, forKey: .weeklyGoalFirstConfiguredAt)
        rewardedWeeklyGoalIDs = try values.decodeIfPresent(Set<UUID>.self, forKey: .rewardedWeeklyGoalIDs) ?? []
        safetyGuidanceDismissedAt = try values.decodeIfPresent(Date.self, forKey: .safetyGuidanceDismissedAt)
        alarmSound = try values.decodeIfPresent(AlarmSoundChoice.self, forKey: .alarmSound) ?? .system
        alarmResults = try values.decodeIfPresent([AlarmResult].self, forKey: .alarmResults) ?? []
    }
}

@MainActor
final class AppPreferencesStore {
    private let defaults: UserDefaults
    private let key = "NemuChart.AppPreferenceData.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> AppPreferenceData {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(AppPreferenceData.self, from: data) else {
            return AppPreferenceData()
        }
        return value
    }

    func save(_ value: AppPreferenceData) throws {
        do { defaults.set(try JSONEncoder().encode(value), forKey: key) }
        catch { throw RepositoryError.persistenceFailed(error.localizedDescription) }
    }

    func deleteAll() { defaults.removeObject(forKey: key) }
}
