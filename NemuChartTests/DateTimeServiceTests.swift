import XCTest
@testable import NemuChart

final class DateTimeServiceTests: XCTestCase {
    private let service = DateTimeService()

    func testOvernightSleepUsesWakeDateAsSleepDay() throws {
        let start = TestFixtures.date(2026, 7, 13, 23, 30)
        let wake = TestFixtures.date(2026, 7, 14, 7, 0)

        let sleepDay = try service.sleepDay(for: wake, timeZoneIdentifier: "Asia/Tokyo")

        XCTAssertEqual(sleepDay.key, "2026-07-14")
        XCTAssertEqual(try service.sleepDuration(from: start, to: wake), 7.5 * 60 * 60)
    }

    func testDSTDurationUsesAbsoluteElapsedTime() throws {
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let start = TestFixtures.date(2026, 3, 8, 1, 30, timeZone: zone)
        let wake = TestFixtures.date(2026, 3, 8, 3, 30, timeZone: zone)

        XCTAssertEqual(try service.sleepDuration(from: start, to: wake), 60 * 60)
    }

    func testSameInstantBelongsToLocalDayInRecordedTimeZone() throws {
        let instant = TestFixtures.date(2026, 7, 14, 0, 30)

        let tokyoDay = try service.sleepDay(for: instant, timeZoneIdentifier: "Asia/Tokyo")
        let losAngelesDay = try service.sleepDay(
            for: instant,
            timeZoneIdentifier: "America/Los_Angeles"
        )

        XCTAssertEqual(tokyoDay.key, "2026-07-14")
        XCTAssertEqual(losAngelesDay.key, "2026-07-13")
    }

    func testRejectsNonPositiveAndOver24HourDurations() {
        let date = TestFixtures.date(2026, 7, 14, 7, 0)
        XCTAssertThrowsError(try service.sleepDuration(from: date, to: date))
        XCTAssertThrowsError(
            try service.sleepDuration(from: date.addingTimeInterval(-25 * 60 * 60), to: date)
        )
    }
}

