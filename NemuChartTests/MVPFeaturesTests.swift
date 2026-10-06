import XCTest
import UIKit
@testable import NemuChart

final class MVPFeaturesTests: XCTestCase {
    func testLogoResourceCanBeLoaded() {
        XCTAssertNotNil(UIImage(named: "NemuChartLogoCropped"))
    }

    func testAppSupportsPortraitOnlyAtRuntime() {
        let delegate = AppOrientationDelegate()

        XCTAssertEqual(delegate.application(UIApplication.shared, supportedInterfaceOrientationsFor: nil), .portrait)
    }

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

        XCTAssertEqual(record.bedTime, TestFixtures.date(2026, 7, 13, 23, 30))
        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 13, 23, 30))
        XCTAssertEqual(record.wakeTime, TestFixtures.date(2026, 7, 14, 7, 0))
    }

    func testDraftUsesSleepClockAsBedTime() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.bedClock = TestFixtures.date(2026, 7, 14, 23, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 14, 22, 30)

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )

        XCTAssertEqual(record.bedTime, TestFixtures.date(2026, 7, 13, 22, 30))
        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 13, 22, 30))
    }

    func testAlarmNightOverridesTimesFromEarlierRecord() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 13, 8, 0))
        draft.sleepClock = TestFixtures.date(2026, 7, 12, 22, 0)
        draft.snoozeCount = 1

        draft.applyAlarmNight(
            wake: TestFixtures.date(2026, 7, 14, 6, 45),
            wentToBed: TestFixtures.date(2026, 7, 13, 23, 20),
            snoozeCount: 2
        )
        let record = try draft.makeRecord(now: TestFixtures.date(2026, 7, 14, 7, 0), timeZone: TestFixtures.tokyo)

        XCTAssertEqual(record.sleepDay.key, "2026-07-14")
        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 13, 23, 20))
        XCTAssertEqual(record.bedTime, TestFixtures.date(2026, 7, 13, 23, 20))
        XCTAssertEqual(record.wakeTime, TestFixtures.date(2026, 7, 14, 6, 45))
        XCTAssertEqual(record.factors.snoozeCount, 2)
    }

    func testDraftKeepsUntouchedOptionalFieldsUnset() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 14, 23, 30)

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )

        XCTAssertNil(record.factors.awakeningCount)
        XCTAssertNil(record.factors.snoozeCount)
        XCTAssertNil(record.factors.secondSleepMinutes)
        XCTAssertNil(record.factors.napMinutes)
        XCTAssertNil(record.factors.consumedAlcohol)
        XCTAssertNil(record.factors.consumedCaffeine)
        XCTAssertNil(record.factors.stress)
        XCTAssertNil(record.factors.comfort)
        XCTAssertNil(record.factors.reportedSnoring)
        XCTAssertNil(record.factors.reportedBreathingPause)
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

    func testDraftPreservesExplicitSleepAndSmartphoneDates() throws {
        var draft = SleepRecordDraft(now: TestFixtures.date(2026, 7, 14, 7, 0))
        draft.wakeTime = TestFixtures.date(2026, 7, 14, 7, 0)
        draft.sleepClock = TestFixtures.date(2026, 7, 13, 23, 30)
        draft.smartphoneEndTime = TestFixtures.date(2026, 7, 13, 22, 20)

        let record = try draft.makeRecord(
            now: TestFixtures.date(2026, 7, 14, 8, 0),
            timeZone: TestFixtures.tokyo
        )

        XCTAssertEqual(record.sleepStart, TestFixtures.date(2026, 7, 13, 23, 30))
        XCTAssertEqual(record.factors.smartphoneEndTime, TestFixtures.date(2026, 7, 13, 22, 20))
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
        XCTAssertTrue(score.components.contains { $0.kind == .continuity })
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
        XCTAssertEqual(score.ruleVersion, "2.0.0")
    }
}
