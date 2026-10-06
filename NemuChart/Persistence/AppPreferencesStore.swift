import Foundation

struct AppPreferenceData: Codable, Equatable {
    var actionGoal: DailyActionGoal?
    var weeklyGoal: WeeklyGoal?
    var weeklyGoalFirstConfiguredAt: Date?
    var rewardedWeeklyGoalIDs: Set<UUID> = []
    var safetyGuidanceDismissedAt: Date?
    var alarmSound: AlarmSoundChoice = .system
    var alarmResults: [AlarmResult] = []
    var customWeeklyGoalText: String = ""
    var customWeeklyGoalCompleted: Bool = false
    var unlockedContentIDs: Set<String> = []
    var growthEarnings: [UUID: SheepGrowthService.Earning] = [:]
    var weeklyGoalHistory: [WeeklyGoal] = []

    private enum CodingKeys: String, CodingKey {
        case actionGoal, weeklyGoal, weeklyGoalFirstConfiguredAt, rewardedWeeklyGoalIDs, safetyGuidanceDismissedAt
        case alarmSound, alarmResults, customWeeklyGoalText, customWeeklyGoalCompleted, unlockedContentIDs, growthEarnings, weeklyGoalHistory
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
        customWeeklyGoalText = try values.decodeIfPresent(String.self, forKey: .customWeeklyGoalText) ?? ""
        customWeeklyGoalCompleted = try values.decodeIfPresent(Bool.self, forKey: .customWeeklyGoalCompleted) ?? false
        let savedIDs = try values.decodeIfPresent(Set<String>.self, forKey: .unlockedContentIDs) ?? []
        unlockedContentIDs = Set(savedIDs.map { SheepCollectible.legacyAccessoryIDs[$0] ?? $0 })
        growthEarnings = try values.decodeIfPresent([UUID: SheepGrowthService.Earning].self, forKey: .growthEarnings) ?? [:]
        weeklyGoalHistory = try values.decodeIfPresent([WeeklyGoal].self, forKey: .weeklyGoalHistory) ?? []
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
