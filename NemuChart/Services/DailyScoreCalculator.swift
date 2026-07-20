import Foundation

struct DailyScoreCalculator: ScoringServiceProtocol {
    static let ruleVersion = "1.0.0"

    func score(record: SleepRecord, settings: UserSettings) throws -> DailySleepScore {
        if record.isAllNighter {
            return try DailySleepScore(
                sleepDay: record.sleepDay,
                total: 0,
                components: [
                    try ScoreComponent(kind: .duration, points: 0, possiblePoints: 44),
                    try ScoreComponent(kind: .timing, points: 0, possiblePoints: 28),
                    try ScoreComponent(kind: .freshness, points: 0, possiblePoints: 28)
                ],
                ruleVersion: Self.ruleVersion
            )
        }
        let hasContinuity = record.factors.awakeningCount != nil
        let weights: [(ScoreComponent.Kind, Int)] = hasContinuity
            ? [(.duration, 40), (.timing, 25), (.freshness, 25), (.continuity, 10)]
            : [(.duration, 44), (.timing, 28), (.freshness, 28)]

        let components = try weights.map { kind, possible in
            let ratio: Double
            switch kind {
            case .duration:
                let difference = abs(record.sleepDuration - settings.desiredSleepDuration)
                ratio = max(0, 1 - difference / (4 * 60 * 60))
            case .timing:
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
                let wakeMinutes = calendar.component(.hour, from: record.wakeTime) * 60
                    + calendar.component(.minute, from: record.wakeTime)
                let target = settings.standardWakeTime.minutesSinceMidnight
                let directDifference = abs(wakeMinutes - target)
                let circularDifference = min(directDifference, 24 * 60 - directDifference)
                ratio = max(0, 1 - Double(circularDifference) / 180)
            case .freshness:
                ratio = Double(record.freshness.rawValue - 1) / 4
            case .continuity:
                ratio = max(0, 1 - Double(record.factors.awakeningCount ?? 0) / 5)
            }
            return try ScoreComponent(
                kind: kind,
                points: Int((Double(possible) * ratio).rounded()),
                possiblePoints: possible
            )
        }

        return try DailySleepScore(
            sleepDay: record.sleepDay,
            total: components.reduce(0) { $0 + $1.points },
            components: components,
            ruleVersion: Self.ruleVersion
        )
    }
}
