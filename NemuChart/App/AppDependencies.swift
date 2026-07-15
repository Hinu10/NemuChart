import SwiftData

@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let sleepRecordRepository: any SleepRecordRepository
    let userSettingsRepository: any UserSettingsRepository
    let sleepGoalRepository: any SleepGoalRepository
    let dateTimeService: any DateTimeServiceProtocol
    let scoringService: any ScoringServiceProtocol
    let feedbackService: SheepFeedbackService
    let weeklyAnalysisService: WeeklyAnalysisService
    let vitalityService: SheepVitalityService
    let growthService: SheepGrowthService
    let landscapeService: LandscapeStateService

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        sleepRecordRepository = SwiftDataSleepRecordRepository(context: context)
        userSettingsRepository = SwiftDataUserSettingsRepository(context: context)
        sleepGoalRepository = SwiftDataSleepGoalRepository(context: context)
        dateTimeService = DateTimeService()
        scoringService = DailyScoreCalculator()
        feedbackService = SheepFeedbackService()
        weeklyAnalysisService = WeeklyAnalysisService()
        vitalityService = SheepVitalityService()
        growthService = SheepGrowthService()
        landscapeService = LandscapeStateService()
    }

    static func live() throws -> AppDependencies {
        AppDependencies(modelContainer: try ModelContainerFactory.make())
    }
}
