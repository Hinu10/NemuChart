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
    let goalPlanningService: GoalPlanningService
    let weeklyGoalProgressService: WeeklyGoalProgressService
    let notificationService: any LocalNotificationServiceProtocol
    let preferences: AppPreferencesStore
    let safetyGuidanceService: SafetyGuidanceService
    let lifestyleAssociationService: LifestyleAssociationService
    let longTermReportService: LongTermReportService
    let exportService: SleepDataExportService
    let premiumEntitlementService: PremiumEntitlementService

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
        goalPlanningService = GoalPlanningService()
        weeklyGoalProgressService = WeeklyGoalProgressService()
        notificationService = LocalNotificationService()
        preferences = AppPreferencesStore()
        safetyGuidanceService = SafetyGuidanceService()
        lifestyleAssociationService = LifestyleAssociationService()
        longTermReportService = LongTermReportService()
        exportService = SleepDataExportService()
        premiumEntitlementService = PremiumEntitlementService()
    }

    static func live() throws -> AppDependencies {
        AppDependencies(modelContainer: try ModelContainerFactory.make())
    }
}
