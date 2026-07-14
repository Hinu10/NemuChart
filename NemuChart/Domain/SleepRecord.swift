import Foundation

struct SleepFactors: Codable, Equatable, Sendable {
    var awakeningCount: Int?
    var snoozeCount: Int?
    var secondSleepMinutes: Int?
    var napMinutes: Int?
    var consumedAlcohol: Bool?
    var consumedCaffeine: Bool?
    var smartphoneEndTime: Date?
    var stress: Rating?
    var comfort: Rating?

    init(
        awakeningCount: Int? = nil,
        snoozeCount: Int? = nil,
        secondSleepMinutes: Int? = nil,
        napMinutes: Int? = nil,
        consumedAlcohol: Bool? = nil,
        consumedCaffeine: Bool? = nil,
        smartphoneEndTime: Date? = nil,
        stress: Rating? = nil,
        comfort: Rating? = nil
    ) throws {
        let nonNegativeValues = [awakeningCount, snoozeCount, secondSleepMinutes, napMinutes]
        guard nonNegativeValues.compactMap({ $0 }).allSatisfy({ $0 >= 0 }) else {
            throw SleepRecordValidationError.negativeFactor
        }
        guard awakeningCount.map({ $0 <= 100 }) ?? true,
              snoozeCount.map({ $0 <= 100 }) ?? true,
              secondSleepMinutes.map({ $0 <= 24 * 60 }) ?? true,
              napMinutes.map({ $0 <= 24 * 60 }) ?? true else {
            throw SleepRecordValidationError.factorOutOfRange
        }

        self.awakeningCount = awakeningCount
        self.snoozeCount = snoozeCount
        self.secondSleepMinutes = secondSleepMinutes
        self.napMinutes = napMinutes
        self.consumedAlcohol = consumedAlcohol
        self.consumedCaffeine = consumedCaffeine
        self.smartphoneEndTime = smartphoneEndTime
        self.stress = stress
        self.comfort = comfort
    }
}

struct SleepRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sleepDay: SleepDay
    var bedTime: Date
    var sleepStart: Date
    var wakeTime: Date
    var freshness: Freshness
    var factors: SleepFactors
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sleepDay: SleepDay,
        bedTime: Date,
        sleepStart: Date,
        wakeTime: Date,
        freshness: Freshness,
        factors: SleepFactors = try! SleepFactors(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dateTimeService: any DateTimeServiceProtocol = DateTimeService()
    ) throws {
        guard bedTime <= sleepStart else {
            throw SleepRecordValidationError.sleepBeforeBed
        }
        _ = try dateTimeService.sleepDuration(from: sleepStart, to: wakeTime)
        let derivedDay = try dateTimeService.sleepDay(
            for: wakeTime,
            timeZoneIdentifier: sleepDay.timeZoneIdentifier
        )
        guard derivedDay.key == sleepDay.key else {
            throw SleepRecordValidationError.sleepDayDoesNotMatchWakeTime
        }
        guard createdAt <= updatedAt else {
            throw SleepRecordValidationError.invalidTimestamps
        }

        self.id = id
        self.sleepDay = sleepDay
        self.bedTime = bedTime
        self.sleepStart = sleepStart
        self.wakeTime = wakeTime
        self.freshness = freshness
        self.factors = factors
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sleepDuration: TimeInterval { wakeTime.timeIntervalSince(sleepStart) }
}

enum SleepRecordValidationError: Error, Equatable, LocalizedError {
    case sleepBeforeBed
    case sleepDayDoesNotMatchWakeTime
    case invalidTimestamps
    case negativeFactor
    case factorOutOfRange

    var errorDescription: String? {
        switch self {
        case .sleepBeforeBed: "入眠時刻はベッド時刻以降にしてください。"
        case .sleepDayDoesNotMatchWakeTime: "睡眠日と起床時刻が一致しません。"
        case .invalidTimestamps: "更新日時は作成日時以降にしてください。"
        case .negativeFactor: "回数や時間に負の値は指定できません。"
        case .factorOutOfRange: "入力値が許容範囲を超えています。"
        }
    }
}

