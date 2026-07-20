import XCTest
@testable import NemuChart

final class MVPFeaturesTests: XCTestCase {
    func testTimeOfDayBoundaries() {
        let policy = TimeOfDayPolicy()
        XCTAssertEqual(policy.period(at: TestFixtures.date(2026, 7, 14, 3, 59), timeZone: TestFixtures.tokyo), .night)
        XCTAssertEqual(policy.period(at: TestFixtures.date(2026, 7, 14, 4, 0), timeZone: TestFixtures.tokyo), .morning)
        XCTAssertEqual(policy.period(at: TestFixtures.date(2026, 7, 14, 12, 0), timeZone: TestFixtures.tokyo), .daytime)
        XCTAssertEqual(policy.period(at: TestFixtures.date(2026, 7, 14, 18, 0), timeZone: TestFixtures.tokyo), .evening)
        XCTAssertEqual(policy.period(at: TestFixtures.date(2026, 7, 14, 22, 0), timeZone: TestFixtures.tokyo), .night)
    }

    func testDraftBuildsOvernightDates() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.bedClock = TestFixtures.date(2026, 7, 14, 23, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 14, 23, 30)

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )

        XCTAssertEqual(record.bedTime, TestFixtures.date(2026, 7, 13, 23, 0))
        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 13, 23, 30))
        XCTAssertEqual(record.wakeTime, TestFixtures.date(2026, 7, 14, 7, 0))
    }

    func testDraftRejectsSleepBeforeBedWithoutSilentCorrection() {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.bedClock = TestFixtures.date(2026, 7, 14, 23, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 14, 22, 30)

        XCTAssertThrowsError(try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )) { error in
            XCTAssertEqual(error as? SleepRecordValidationError, .sleepBeforeBed)
        }
    }

    func testDraftLatencyMode() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.bedClock = TestFixtures.date(2026, 7, 14, 23, 0)
        draft.sleepStartInputMode = .latency
        draft.latencyMinutes = 25

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )
        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 13, 23, 25))
    }

    func testDraftNormalizesSmartphoneClockToPreviousNight() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.bedClock = TestFixtures.date(2026, 7, 14, 23, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 14, 23, 30)
        draft.smartphoneEndTime = TestFixtures.date(2026, 7, 14, 22, 30)

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )
        XCTAssertEqual(record.factors.smartphoneEndTime, TestFixtures.date(2026, 7, 13, 22, 30))
    }

    func testAllNighterDraftCreatesZeroDurationRecordAndZeroScore() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.inputKind = .allNighter
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )
        let settings = try UserSettings(
            desiredSleepDuration: 8 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!
        )
        let score = try DailyScoreCalculator().score(record: record, settings: settings)

        XCTAssertTrue(record.isAllNighter)
        XCTAssertEqual(record.sleepDuration, 0)
        XCTAssertEqual(record.freshness, .veryTired)
        XCTAssertEqual(score.total, 0)
        XCTAssertEqual(score.components.reduce(0) { $0 + $1.possiblePoints }, 100)
    }

    func testLegacySleepFactorsDecodeWithoutAllNighterField() throws {
        let factors = try JSONDecoder().decode(SleepFactors.self, from: Data("{}".utf8))
        XCTAssertNil(factors.isAllNighter)
        XCTAssertFalse(factors.isAllNighter == true)
    }

    func testPerfectDailyScoreIs100() throws {
        let factors = try SleepFactors(awakeningCount: 0)
        let day = try SleepDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Tokyo")
        let record = try SleepRecord(
            sleepDay: day,
            bedTime: TestFixtures.date(2026, 7, 13, 22, 45),
            sleepStart: TestFixtures.date(2026, 7, 13, 23, 0),
            wakeTime: TestFixtures.date(2026, 7, 14, 7, 0),
            freshness: .veryRefreshed,
            factors: factors
        )
        let settings = try UserSettings(
            desiredSleepDuration: 8 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!
        )

        let score = try DailyScoreCalculator().score(record: record, settings: settings)
        XCTAssertEqual(score.total, 100)
        XCTAssertEqual(score.components.reduce(0) { $0 + $1.possiblePoints }, 100)
    }

    func testMissingContinuityIsRedistributed() throws {
        let record = try TestFixtures.sleepRecord(freshness: .veryRefreshed)
        let settings = try UserSettings(
            desiredSleepDuration: 7.5 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!
        )
        let score = try DailyScoreCalculator().score(record: record, settings: settings)

        XCTAssertEqual(score.total, 100)
        XCTAssertFalse(score.components.contains { $0.kind == .continuity })
        XCTAssertEqual(score.components.reduce(0) { $0 + $1.possiblePoints }, 100)
    }

    func testExtremeValuesRemainInScoreRange() throws {
        let record = try TestFixtures.sleepRecord(freshness: .veryTired)
        let settings = try UserSettings(
            desiredSleepDuration: 16 * 3600,
            standardWakeTime: LocalTime(hour: 19, minute: 0)!
        )
        let score = try DailyScoreCalculator().score(record: record, settings: settings)
        XCTAssertTrue((0...100).contains(score.total))
        XCTAssertEqual(score.ruleVersion, "1.0.0")
    }
}
