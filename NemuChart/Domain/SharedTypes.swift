import Foundation

struct LocalTime: Codable, Hashable, Sendable {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }
}

enum WeekStart: Int, Codable, CaseIterable, Sendable {
    case sunday = 1
    case monday = 2
}

enum Freshness: Int, Codable, CaseIterable, Sendable {
    case veryTired = 1
    case tired
    case neutral
    case refreshed
    case veryRefreshed
}

enum Rating: Int, Codable, CaseIterable, Sendable {
    case veryLow = 1
    case low
    case medium
    case high
    case veryHigh
}

struct Clock: Sendable {
    var now: @Sendable () -> Date

    static let live = Clock(now: { Date() })
}
