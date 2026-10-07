import Foundation

enum SleepStartInputMode: String, CaseIterable, Identifiable {
    case clockTime
    case latency

    var id: Self { self }
}

enum SleepRecordInputKind: String, CaseIterable, Identifiable {
    case slept
    case allNighter

    var id: Self { self }
}

struct SleepRecordDraft {
    var inputKind: SleepRecordInputKind = .slept
    var wakeTime: Date
    var recordDate: Date
    var manuallyAdjustDates = false
    var bedClock: Date
    var sleepClock: Date
    var sleepStartInputMode: SleepStartInputMode = .clockTime
    var latencyMinutes = 20
    var freshness: Freshness = .neutral
    var freshnessRate = 50
    var awakeningCount = 0
    var snoozeCount = 0
    var secondSleepMinutes: Int?
    var napMinutes = 0
    var consumedAlcohol = false
    var consumedCaffeine = false
    /// 入力欄はなくしたが、以前の記録を編集して保存しても値が消えないよう引き継ぐ。
    var smartphoneEndTime: Date?
    var stress: Rating = .medium
    var comfort: Rating = .medium
    var reportedSnoring = false
    var reportedBreathingPause = false
    var id = UUID()
    var createdAt = Date()

    init(now: Date = Date(), calendar: Calendar = .current) {
        id = UUID()
        createdAt = now
        wakeTime = now
        recordDate = now
        bedClock = calendar.date(byAdding: .hour, value: -8, to: now) ?? now
        sleepClock = calendar.date(byAdding: .hour, value: -7, to: now) ?? now
    }

    init(record: SleepRecord) {
        inputKind = record.isAllNighter ? .allNighter : .slept
        wakeTime = record.wakeTime
        recordDate = record.wakeTime
        bedClock = record.bedTime
        sleepClock = record.sleepStart
        freshness = record.freshness
        freshnessRate = record.freshnessValue
        awakeningCount = record.factors.awakeningCount ?? 0
        snoozeCount = record.factors.snoozeCount ?? 0
        secondSleepMinutes = record.factors.secondSleepMinutes
        napMinutes = record.factors.napMinutes ?? 0
        consumedAlcohol = record.factors.consumedAlcohol ?? false
        consumedCaffeine = record.factors.consumedCaffeine ?? false
        smartphoneEndTime = record.factors.smartphoneEndTime
        stress = record.factors.stress ?? .medium
        comfort = record.factors.comfort ?? .medium
        reportedSnoring = record.factors.reportedSnoring ?? false
        reportedBreathingPause = record.factors.reportedBreathingPause ?? false
        id = record.id
        createdAt = record.createdAt
    }

    /// アラームの「起きた！」から開いたとき、その夜に分かった時刻で上書きする。
    /// 寝た時刻は「今から寝る」を押した時刻、起きた時刻は「起きた！」を押した時刻。保存前に記録画面で直せる。
    mutating func applyAlarmNight(wake: Date, wentToBed: Date?, snoozeCount: Int?) {
        wakeTime = wake
        recordDate = wake
        if let wentToBed {
            bedClock = wentToBed
            sleepClock = wentToBed
            sleepStartInputMode = .clockTime
            manuallyAdjustDates = false
        }
        if let snoozeCount { self.snoozeCount = snoozeCount }
    }

    func makeRecord(
        now: Date = Date(),
        timeZone: TimeZone = .current,
        dateTimeService: any DateTimeServiceProtocol = DateTimeService()
    ) throws -> SleepRecord {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = try dateTimeService.sleepDay(
            for: recordDate,
            timeZoneIdentifier: timeZone.identifier
        )
        let wake = try Self.date(matchingClock: wakeTime, on: day, calendar: calendar)
        guard wake <= now.addingTimeInterval(5 * 60) else {
            throw SleepDraftValidationError.wakeTimeInFuture
        }
        if inputKind == .allNighter {
            let factors = try SleepFactors(isAllNighter: true)
            return try SleepRecord(
                id: id,
                sleepDay: day,
                bedTime: wake,
                sleepStart: wake,
                wakeTime: wake,
                freshness: .veryTired,
                factors: factors,
                createdAt: createdAt,
                updatedAt: now,
                dateTimeService: dateTimeService
            )
        }
        let sleepStart: Date
        if manuallyAdjustDates {
            sleepStart = sleepClock
        } else {
            let sameDay = try Self.date(matchingClock: sleepClock, on: day, calendar: calendar)
            sleepStart = sameDay >= wake ? calendar.date(byAdding: .day, value: -1, to: sameDay)! : sameDay
        }
        let bed = sleepStart

        var normalizedSmartphoneEndTime: Date?
        if let smartphoneEndTime {
            normalizedSmartphoneEndTime = Self.normalizedDate(
                smartphoneEndTime,
                wake: wake,
                sleepDay: day,
                calendar: calendar
            )
        }
        let factors = try SleepFactors(
            isAllNighter: false,
            awakeningCount: awakeningCount,
            snoozeCount: snoozeCount,
            secondSleepMinutes: secondSleepMinutes,
            napMinutes: napMinutes,
            consumedAlcohol: consumedAlcohol,
            consumedCaffeine: consumedCaffeine,
            smartphoneEndTime: normalizedSmartphoneEndTime,
            stress: stress,
            comfort: comfort,
            freshnessRate: freshnessRate,
            reportedSnoring: reportedSnoring,
            reportedBreathingPause: reportedBreathingPause
        )
        return try SleepRecord(
            id: id,
            sleepDay: day,
            bedTime: bed,
            sleepStart: sleepStart,
            wakeTime: wake,
            freshness: Freshness(rawValue: min(5, max(1, Int((Double(freshnessRate) / 25).rounded()) + 1))) ?? .neutral,
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

    private static func normalizedDate(
        _ date: Date,
        wake: Date,
        sleepDay: SleepDay,
        calendar: Calendar
    ) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let isOnSleepDay = components.year == sleepDay.year
            && components.month == sleepDay.month
            && components.day == sleepDay.day
        if isOnSleepDay, date >= wake {
            return calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return date
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
