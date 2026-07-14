import SwiftData

@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let sleepRecordRepository: any SleepRecordRepository
    let userSettingsRepository: any UserSettingsRepository
    let sleepGoalRepository: any SleepGoalRepository
    let dateTimeService: any DateTimeServiceProtocol

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        sleepRecordRepository = SwiftDataSleepRecordRepository(context: context)
        userSettingsRepository = SwiftDataUserSettingsRepository(context: context)
        sleepGoalRepository = SwiftDataSleepGoalRepository(context: context)
        dateTimeService = DateTimeService()
    }

    static func live() throws -> AppDependencies {
        AppDependencies(modelContainer: try ModelContainerFactory.make())
    }
}

