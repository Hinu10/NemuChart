import SwiftData
import XCTest
@testable import NemuChart

@MainActor
final class MVPIntegrationTests: XCTestCase {
    func testOnboardingRecordScoreWeeklyReportAndDeletionFlow() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let dependencies = AppDependencies(modelContainer: container)
        let settings = try UserSettings(
            hasCompletedOnboarding: true,
            desiredSleepDuration: 7.5 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!
        )
        try dependencies.userSettingsRepository.save(settings)
        let record = try TestFixtures.sleepRecord()
        guard case .created = try dependencies.sleepRecordRepository.save(record) else {
            return XCTFail("記録が新規保存される必要があります")
        }

        let score = try dependencies.scoringService.score(record: record, settings: settings)
        XCTAssertTrue((0...100).contains(score.total))
        let metrics = try dependencies.weeklyAnalysisService.metrics(
            records: try dependencies.sleepRecordRepository.records(),
            endDay: record.sleepDay,
            settings: settings,
            scoringService: dependencies.scoringService
        )
        XCTAssertEqual(metrics.recordedDayCount, 1)
        XCTAssertEqual(metrics.weeklyScore, score.total)

        try dependencies.sleepRecordRepository.delete(id: record.id)
        XCTAssertTrue(try dependencies.sleepRecordRepository.records().isEmpty)
        XCTAssertNotNil(try dependencies.userSettingsRepository.load())
    }
}
