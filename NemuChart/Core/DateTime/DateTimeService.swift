import Foundation

protocol DateTimeServiceProtocol: Sendable {
    func sleepDay(for wakeTime: Date, timeZoneIdentifier: String) throws -> SleepDay
    func date(
        on sleepDay: SleepDay,
        localTime: LocalTime,
        dayOffset: Int
    ) throws -> Date
    func sleepDuration(from sleepStart: Date, to wakeTime: Date) throws -> TimeInterval
}

struct DateTimeService: DateTimeServiceProtocol {
    private let calendarIdentifier: Calendar.Identifier
    private let maximumSleepDuration: TimeInterval

    init(
        calendarIdentifier: Calendar.Identifier = .gregorian,
        maximumSleepDuration: TimeInterval = 24 * 60 * 60
    ) {
        self.calendarIdentifier = calendarIdentifier
        self.maximumSleepDuration = maximumSleepDuration
    }

    func sleepDay(for wakeTime: Date, timeZoneIdentifier: String) throws -> SleepDay {
        let calendar = try calendar(timeZoneIdentifier: timeZoneIdentifier)
        let parts = calendar.dateComponents([.year, .month, .day], from: wakeTime)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            throw DateTimeError.invalidDateComponents
        }
        return try SleepDay(
            year: year,
            month: month,
            day: day,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    func date(
        on sleepDay: SleepDay,
        localTime: LocalTime,
        dayOffset: Int = 0
    ) throws -> Date {
        let calendar = try calendar(timeZoneIdentifier: sleepDay.timeZoneIdentifier)
        var day = DateComponents(
            year: sleepDay.year,
            month: sleepDay.month,
            day: sleepDay.day,
            hour: localTime.hour,
            minute: localTime.minute
        )
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        guard let base = calendar.date(from: day),
              let result = calendar.date(byAdding: .day, value: dayOffset, to: base) else {
            throw DateTimeError.invalidDateComponents
        }
        return result
    }

    func sleepDuration(from sleepStart: Date, to wakeTime: Date) throws -> TimeInterval {
        let duration = wakeTime.timeIntervalSince(sleepStart)
        guard duration > 0 else { throw DateTimeError.nonPositiveDuration }
        guard duration <= maximumSleepDuration else { throw DateTimeError.durationExceedsMaximum }
        return duration
    }

    private func calendar(timeZoneIdentifier: String) throws -> Calendar {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw DateTimeError.invalidTimeZone(timeZoneIdentifier)
        }
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.timeZone = timeZone
        return calendar
    }
}

