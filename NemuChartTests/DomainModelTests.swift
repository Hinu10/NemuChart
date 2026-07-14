import XCTest
@testable import NemuChart

final class DomainModelTests: XCTestCase {
    func testOptionalFactorDistinguishesMissingFromNone() throws {
        let missing = try SleepFactors()
        let explicitlyNone = try SleepFactors(
            awakeningCount: 0,
            consumedAlcohol: false
        )

        XCTAssertNil(missing.awakeningCount)
        XCTAssertNil(missing.consumedAlcohol)
        XCTAssertEqual(explicitlyNone.awakeningCount, 0)
        XCTAssertEqual(explicitlyNone.consumedAlcohol, false)
    }

    func testFactorsRejectNegativeValues() {
        XCTAssertThrowsError(try SleepFactors(awakeningCount: -1))
    }

    func testSleepRecordRejectsSleepBeforeBedTime() throws {
        let sleepDay = try SleepDay(
            year: 2026,
            month: 7,
            day: 14,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        XCTAssertThrowsError(try SleepRecord(
            sleepDay: sleepDay,
            bedTime: TestFixtures.date(2026, 7, 14, 0, 0),
            sleepStart: TestFixtures.date(2026, 7, 13, 23, 30),
            wakeTime: TestFixtures.date(2026, 7, 14, 7, 0),
            freshness: .neutral
        ))
    }

    func testDailyScoreAcceptsBoundaryValues() throws {
        let day = try SleepDay(
            year: 2026,
            month: 7,
            day: 14,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        XCTAssertNoThrow(try DailySleepScore(
            sleepDay: day,
            total: 0,
            components: [],
            ruleVersion: "1.0.0"
        ))
        XCTAssertNoThrow(try DailySleepScore(
            sleepDay: day,
            total: 100,
            components: [],
            ruleVersion: "1.0.0"
        ))
        XCTAssertThrowsError(try DailySleepScore(
            sleepDay: day,
            total: 101,
            components: [],
            ruleVersion: "1.0.0"
        ))
    }

    func testGrowthPointsNeverDecreaseOrBecomeNegative() {
        var points = GrowthPoints(-20)
        XCTAssertEqual(points.value, 0)
        points.add(10)
        points.add(-5)
        XCTAssertEqual(points.value, 10)
    }

    func testNotificationPreferenceSeparatesAppChoiceFromOSAuthorization() throws {
        let settings = try UserSettings(
            desiredSleepDuration: 8 * 60 * 60,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!,
            notificationPreference: NotificationPreference(
                isEnabledInApp: true,
                authorizationState: .denied
            )
        )

        XCTAssertTrue(settings.notificationPreference.isEnabledInApp)
        XCTAssertEqual(settings.notificationPreference.authorizationState, .denied)
    }

    func testAnalysisServiceCanBeReplacedWithMock() throws {
        struct MockAnalysisService: AnalysisServiceProtocol {
            let report: WeeklySleepReport
            func weeklyReport(records: [SleepRecord], weekStart: SleepDay) throws -> WeeklySleepReport {
                report
            }
        }

        let start = try SleepDay(year: 2026, month: 7, day: 13, timeZoneIdentifier: "Asia/Tokyo")
        let end = try SleepDay(year: 2026, month: 7, day: 19, timeZoneIdentifier: "Asia/Tokyo")
        let expected = try WeeklySleepReport(
            startDay: start,
            endDay: end,
            recordedDayCount: 0,
            score: nil,
            confidence: .insufficient
        )
        let service: any AnalysisServiceProtocol = MockAnalysisService(report: expected)

        XCTAssertEqual(try service.weeklyReport(records: [], weekStart: start), expected)
    }
}

