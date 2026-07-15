import XCTest
@testable import NemuChart

final class MVPAnalysisAndSheepTests: XCTestCase {
    private let calculator = DailyScoreCalculator()

    func testFeedbackHasOneActionableSuggestionAndAffirmsLowScoreRecording() throws {
        let day = try SleepDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Tokyo")
        let components = [
            try ScoreComponent(kind: .duration, points: 5, possiblePoints: 40),
            try ScoreComponent(kind: .timing, points: 15, possiblePoints: 25),
            try ScoreComponent(kind: .freshness, points: 10, possiblePoints: 25),
            try ScoreComponent(kind: .continuity, points: 8, possiblePoints: 10)
        ]
        let score = try DailySleepScore(sleepDay: day, total: 38, components: components, ruleVersion: "1.0")
        let feedback = SheepFeedbackService().feedback(for: score)

        XCTAssertNotNil(feedback.suggestion)
        XCTAssertTrue(feedback.closing.contains("記録"))
        XCTAssertFalse(feedback.combinedMessage.contains("診断"))
        XCTAssertFalse(feedback.combinedMessage.contains("必ず"))
    }

    func testWeeklyMetricsUseSevenDayWindowAndDoNotCountMissingDaysAsZero() throws {
        let records = try (8...14).filter { $0 != 10 }.map { try TestFixtures.sleepRecord(day: $0) }
        let settings = try makeSettings()
        let end = try SleepDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Tokyo")

        let metrics = try WeeklyAnalysisService().metrics(
            records: records, endDay: end, settings: settings, scoringService: calculator
        )

        XCTAssertEqual(metrics.startDay.key, "2026-07-08")
        XCTAssertEqual(metrics.recordedDayCount, 6)
        XCTAssertEqual(metrics.averageSleepDuration, 7.5 * 3600)
        XCTAssertNotNil(metrics.weeklyScore)
    }

    func testWeeklyMetricsDeduplicateEditedSleepDayAndComparePreviousWeek() throws {
        var records = try (1...7).map { try TestFixtures.sleepRecord(day: $0, freshness: .veryTired) }
        records += try (8...14).map { try TestFixtures.sleepRecord(day: $0, freshness: .veryRefreshed) }
        records.append(try TestFixtures.sleepRecord(
            id: UUID(), day: 14, freshness: .veryRefreshed,
            createdAt: TestFixtures.date(2026, 7, 14, 9, 0),
            updatedAt: TestFixtures.date(2026, 7, 14, 9, 0)
        ))
        let end = try SleepDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Tokyo")
        let metrics = try WeeklyAnalysisService().metrics(
            records: records, endDay: end, settings: makeSettings(), scoringService: calculator
        )

        XCTAssertEqual(metrics.recordedDayCount, 7)
        XCTAssertEqual(metrics.recordsByDay.count, 7)
        XCTAssertGreaterThan(metrics.previousWeekScoreDifference ?? 0, 0)
    }

    func testConfidenceThresholdsAndMissingOptionalData() throws {
        let service = WeeklyAnalysisService()
        let end = try SleepDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Tokyo")
        let two = try (13...14).map { try TestFixtures.sleepRecord(day: $0) }
        let seven = try (8...14).map { try TestFixtures.sleepRecord(day: $0) }

        let insufficient = try service.metrics(records: two, endDay: end, settings: makeSettings(), scoringService: calculator)
        let missingOptional = try service.metrics(records: seven, endDay: end, settings: makeSettings(), scoringService: calculator)

        XCTAssertEqual(insufficient.confidence.level, .insufficient)
        XCTAssertEqual(missingOptional.confidence.level, .low)
        XCTAssertFalse(missingOptional.confidence.reason.isEmpty)
    }

    func testComfortEstimateRequiresTenRecordsAndReturnsThirtyMinuteRange() throws {
        let service = WeeklyAnalysisService()
        let nine = try (1...9).map { try TestFixtures.sleepRecord(day: $0, freshness: .refreshed) }
        let ten = try (1...10).map { try TestFixtures.sleepRecord(day: $0, freshness: .refreshed) }

        XCTAssertNil(service.comfortableDurationEstimate(records: nine))
        let estimate = try XCTUnwrap(service.comfortableDurationEstimate(records: ten))
        XCTAssertEqual(estimate.upperBoundMinutes - estimate.lowerBoundMinutes, 30)
        XCTAssertEqual(estimate.sampleCount, 10)
        XCTAssertTrue(estimate.explanation.contains("傾向"))
    }

    func testVitalityIgnoresSingleLowDayAndRecoversQuickly() throws {
        let service = SheepVitalityService()
        XCTAssertEqual(service.vitality(scores: [try makeScore(30)]), .calm)
        XCTAssertEqual(service.vitality(scores: [try makeScore(30), try makeScore(35), try makeScore(40)]), .resting)
        XCTAssertEqual(service.vitality(scores: [try makeScore(75), try makeScore(35), try makeScore(40)]), .lively)
        XCTAssertEqual(service.vitality(scores: [try makeScore(85), try makeScore(82)]), .radiant)
    }

    func testGrowthDeduplicatesRecordsAndNeverMovesBackwardForLowScores() {
        let service = SheepGrowthService()
        let id = UUID()
        let one = service.summary(recordIDs: [id])
        let duplicated = service.summary(recordIDs: [id, id])
        let grown = service.summary(recordIDs: (0..<15).map { _ in UUID() })

        XCTAssertEqual(one, duplicated)
        XCTAssertEqual(one.points.value, 10)
        XCTAssertEqual(grown.stage, .grown)
        XCTAssertEqual(grown.points.value, 150)
    }

    func testLandscapeKeepsTimeAndMoodAsIndependentAxes() {
        let service = LandscapeStateService()
        for time in [HomeTimeOfDay.morning, .daytime, .evening, .night] {
            XCTAssertEqual(service.state(timeOfDay: time, vitality: .radiant), LandscapeState(timeOfDay: time, mood: .clear))
            XCTAssertEqual(service.state(timeOfDay: time, vitality: .calm), LandscapeState(timeOfDay: time, mood: .gentle))
            XCTAssertEqual(service.state(timeOfDay: time, vitality: .resting), LandscapeState(timeOfDay: time, mood: .cloudy))
        }
    }

    private func makeSettings() throws -> UserSettings {
        try UserSettings(desiredSleepDuration: 7.5 * 3600, standardWakeTime: LocalTime(hour: 7, minute: 0)!)
    }

    private func makeScore(_ total: Int) throws -> DailySleepScore {
        let day = try SleepDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Tokyo")
        return try DailySleepScore(
            sleepDay: day,
            total: total,
            components: [try ScoreComponent(kind: .duration, points: total, possiblePoints: 100)],
            ruleVersion: "test"
        )
    }
}
