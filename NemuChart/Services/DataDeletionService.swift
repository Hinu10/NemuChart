import Foundation

@MainActor
struct DataDeletionService {
    let sleepRecordRepository: any SleepRecordRepository
    let userSettingsRepository: any UserSettingsRepository
    let sleepGoalRepository: any SleepGoalRepository
    let preferences: AppPreferencesStore

    func deleteAll() throws {
        for record in try sleepRecordRepository.records() { try sleepRecordRepository.delete(id: record.id) }
        for goal in try sleepGoalRepository.goals() { try sleepGoalRepository.delete(id: goal.id) }
        try userSettingsRepository.delete()
        preferences.deleteAll()
    }
}
