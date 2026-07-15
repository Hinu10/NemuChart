import Foundation

enum SleepStartInputMode: String, CaseIterable, Identifiable {
    case clockTime
    case latency

    var id: Self { self }
}

struct SleepRecordDraft {
    var wakeTime: Date
    var bedClock: Date
    var sleepClock: Date
    var sleepStartInputMode: SleepStartInputMode = .clockTime
    var latencyMinutes = 20
    var freshness: Freshness = .neutral
    var awakeningCount: Int?
    var snoozeCount: Int?
    var secondSleepMinutes: Int?
    var napMinutes: Int?
    var consumedAlcohol: Bool?
    var consumedCaffeine: Bool?
    var smartphoneEndTime: Date?
    var stress: Rating?
    var comfort: Rating?
    var id = UUID()
    var createdAt = Date()

    init(now: Date = Date(), calendar: Calendar = .current) {
        id = UUID()
        createdAt = now
        wakeTime = now
        bedClock = calendar.date(byAdding: .hour, value: -8, to: now) ?? now
        sleepClock = calendar.date(byAdding: .hour, value: -7, to: now) ?? now
    }

    init(record: SleepRecord) {
        wakeTime = record.wakeTime
        bedClock = record.bedTime
        sleepClock = record.sleepStart
        freshness = record.freshness
        awakeningCount = record.factors.awakeningCount
        snoozeCount = record.factors.snoozeCount
        secondSleepMinutes = record.factors.secondSleepMinutes
        napMinutes = record.factors.napMinutes
        consumedAlcohol = record.factors.consumedAlcohol
        consumedCaffeine = record.factors.consumedCaffeine
        smartphoneEndTime = record.factors.smartphoneEndTime
        stress = record.factors.stress
        comfort = record.factors.comfort
        id = record.id
        createdAt = record.createdAt
    }

    func makeRecord(
        now: Date = Date(),
        timeZone: TimeZone = .current,
        dateTimeService: any DateTimeServiceProtocol = DateTimeService()
    ) throws -> SleepRecord {
        guard wakeTime <= now.addingTimeInterval(5 * 60) else {
            throw SleepDraftValidationError.wakeTimeInFuture
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = try dateTimeService.sleepDay(
            for: wakeTime,
            timeZoneIdentifier: timeZone.identifier
        )
        let wake = try Self.date(matchingClock: wakeTime, on: day, calendar: calendar)
        var bed = try Self.date(matchingClock: bedClock, on: day, calendar: calendar)
        if bed >= wake { bed = calendar.date(byAdding: .day, value: -1, to: bed)! }

        let sleepStart: Date
        switch sleepStartInputMode {
        case .clockTime:
            var candidate = try Self.date(matchingClock: sleepClock, on: day, calendar: calendar)
            if candidate >= wake { candidate = calendar.date(byAdding: .day, value: -1, to: candidate)! }
            guard candidate >= bed else { throw SleepRecordValidationError.sleepBeforeBed }
            sleepStart = candidate
        case .latency:
            guard (0...240).contains(latencyMinutes) else {
                throw SleepDraftValidationError.invalidLatency
            }
            sleepStart = bed.addingTimeInterval(TimeInterval(latencyMinutes * 60))
        }

        let factors = try SleepFactors(
            awakeningCount: awakeningCount,
            snoozeCount: snoozeCount,
            secondSleepMinutes: secondSleepMinutes,
            napMinutes: napMinutes,
            consumedAlcohol: consumedAlcohol,
            consumedCaffeine: consumedCaffeine,
            smartphoneEndTime: smartphoneEndTime,
            stress: stress,
            comfort: comfort
        )
        return try SleepRecord(
            id: id,
            sleepDay: day,
            bedTime: bed,
            sleepStart: sleepStart,
            wakeTime: wake,
            freshness: freshness,
            factors: factors,
            createdAt: createdAt,
            updatedAt: now,
            dateTimeService: dateTimeService
        )
    }

    private static func date(
        matchingClock clock: Date,
        on day: SleepDay,
        calendar: Calendar
    ) throws -> Date {
        var components = DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: calendar.component(.hour, from: clock),
            minute: calendar.component(.minute, from: clock)
        )
        components.timeZone = calendar.timeZone
        guard let result = calendar.date(from: components) else {
            throw DateTimeError.invalidDateComponents
        }
        return result
    }
}

enum SleepDraftValidationError: LocalizedError, Equatable {
    case wakeTimeInFuture
    case invalidLatency

    var errorDescription: String? {
        switch self {
        case .wakeTimeInFuture: "起床時刻が未来になっています。"
        case .invalidLatency: "入眠までの時間は0〜240分で入力してください。"
        }
    }
}
