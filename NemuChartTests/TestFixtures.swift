import Foundation
@testable import NemuChart

enum TestFixtures {
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        timeZone: TimeZone = tokyo
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    static func sleepRecord(
        id: UUID = UUID(),
        day: Int = 14,
        freshness: Freshness = .refreshed,
        createdAt: Date = date(2026, 7, 14, 8, 0),
        updatedAt: Date = date(2026, 7, 14, 8, 0)
    ) throws -> SleepRecord {
        let sleepDay = try SleepDay(
            year: 2026,
            month: 7,
            day: day,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        return try SleepRecord(
            id: id,
            sleepDay: sleepDay,
            bedTime: date(2026, 7, day - 1, 23, 0),
            sleepStart: date(2026, 7, day - 1, 23, 30),
            wakeTime: date(2026, 7, day, 7, 0),
            freshness: freshness,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

