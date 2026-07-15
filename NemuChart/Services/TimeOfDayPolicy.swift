import Foundation

enum HomeTimeOfDay: Equatable, Sendable {
    case morning
    case daytime
    case evening
    case night
}

struct TimeOfDayPolicy: Sendable {
    func period(at date: Date, timeZone: TimeZone = .current) -> HomeTimeOfDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        switch calendar.component(.hour, from: date) {
        case 4..<12: return .morning
        case 12..<18: return .daytime
        case 18..<22: return .evening
        default: return .night
        }
    }
}
