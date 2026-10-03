import XCTest
@testable import NemuChart

final class NemuChartUpdateTests: XCTestCase {
    private let settings = try! UserSettings(
        desiredSleepDuration: 8 * 3600,
        standardWakeTime: LocalTime(hour: 7, minute: 0)!
    )

    func testScoreWeightsAndLinearBoundaries() throws {
        var record = try TestFixtures.sleepRecord()
        record.sleepStart = TestFixtures.date(2026, 7, 13, 23, 0)
        record.factors = try SleepFactors(awakeningCount: 0, freshnessRate: 100)
        let perfect = try DailyScoreCalculator().score(record: record, settings: settings)
        XCTAssertEqual(perfect.components.map(\.possiblePoints), [45, 25, 25, 5])
        XCTAssertEqual(perfect.total, 100)

        record.sleepStart = TestFixtures.date(2026, 7, 14, 3, 0)
        let short = try DailyScoreCalculator().score(record: record, settings: settings)
        XCTAssertEqual(short.components[0].points, 0)

        record.sleepStart = TestFixtures.date(2026, 7, 13, 18, 30)
        let long = try DailyScoreCalculator().score(record: record, settings: settings)
        XCTAssertEqual(long.components[0].points, 0)

        record.factors = try SleepFactors(awakeningCount: 10, freshnessRate: 50)
        let changed = try DailyScoreCalculator().score(record: record, settings: settings)
        XCTAssertEqual(changed.components[2].points, 13)
        XCTAssertEqual(changed.components[2].exactPoints, 12.5)
        XCTAssertEqual(changed.components[3].points, 0)
    }

    func testPastRecordBridgesStreakAndDeletionReversesGrowth() throws {
        let first = try TestFixtures.sleepRecord(day: 1)
        let bridge = try TestFixtures.sleepRecord(day: 2)
        let third = try TestFixtures.sleepRecord(day: 3)
        let service = SheepGrowthService()
        func earnings(_ records: [SleepRecord]) throws -> [SheepGrowthService.Earning] {
            let scores = try records.map { try DailyScoreCalculator().score(record: $0, settings: settings) }
            return service.earnings(records: records, scores: scores)
        }
        XCTAssertEqual(try earnings([first, third]).last?.streakPoints, 0)
        XCTAssertEqual(try earnings([first, bridge, third]).last?.streakPoints, 1)
        let before = service.summary(earnings: try earnings([first, bridge, third])).points.value
        let after = service.summary(earnings: try earnings([first, third])).points.value
        XCTAssertLessThan(after, before)
    }

    func testLegacyFreshnessAndNewRateCoexist() throws {
        var record = try TestFixtures.sleepRecord(freshness: .neutral)
        XCTAssertEqual(record.freshnessValue, 50)
        record.factors = try SleepFactors(freshnessRate: 70)
        XCTAssertEqual(record.freshnessValue, 70)
        let legacy = try JSONDecoder().decode(SleepFactors.self, from: Data("{}".utf8))
        XCTAssertNil(legacy.freshnessRate)
    }

    func testEarlyMorningClockStaysOnRecordDay() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 10, 0))
        draft.recordDate = TestFixtures.date(2026, 7, 14, 10, 0)
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 10, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 13, 2, 0)
        let record = try draft.makeRecord(now: TestFixtures.date(2026, 7, 14, 11, 0), timeZone: TestFixtures.tokyo)
        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 14, 2, 0))
        XCTAssertEqual(record.sleepDay.key, "2026-07-14")
    }
}
