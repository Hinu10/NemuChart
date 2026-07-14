import Foundation

struct SleepDay: Codable, Hashable, Sendable, Comparable {
    let year: Int
    let month: Int
    let day: Int
    let timeZoneIdentifier: String

    init(year: Int, month: Int, day: Int, timeZoneIdentifier: String) throws {
        guard TimeZone(identifier: timeZoneIdentifier) != nil else {
            throw DateTimeError.invalidTimeZone(timeZoneIdentifier)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components else {
            throw DateTimeError.invalidLocalDate
        }

        self.year = year
        self.month = month
        self.day = day
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func < (lhs: SleepDay, rhs: SleepDay) -> Bool {
        lhs.key < rhs.key
    }
}

enum DateTimeError: Error, Equatable, LocalizedError {
    case invalidTimeZone(String)
    case invalidLocalDate
    case invalidDateComponents
    case nonPositiveDuration
    case durationExceedsMaximum

    var errorDescription: String? {
        switch self {
        case .invalidTimeZone(let identifier): "不明なタイムゾーンです: \(identifier)"
        case .invalidLocalDate: "存在しないローカル日付です。"
        case .invalidDateComponents: "日時を組み立てられません。"
        case .nonPositiveDuration: "起床時刻は入眠時刻より後にしてください。"
        case .durationExceedsMaximum: "睡眠時間が24時間を超えています。"
        }
    }
}

