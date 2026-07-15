import Foundation

struct AppPreferenceData: Codable, Equatable {
    var actionGoal: DailyActionGoal?
    var weeklyGoal: WeeklyGoal?
    var rewardedWeeklyGoalIDs: Set<UUID> = []
    var safetyGuidanceDismissedAt: Date?
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
