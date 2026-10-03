import Foundation

struct DailyScoreCalculator: ScoringServiceProtocol {
    static let ruleVersion = "2.0.0"

    func score(record: SleepRecord, settings: UserSettings) throws -> DailySleepScore {
        if record.isAllNighter {
            return try DailySleepScore(
                sleepDay: record.sleepDay,
                total: 0,
                components: [
                    try ScoreComponent(kind: .duration, points: 0, possiblePoints: 45),
                    try ScoreComponent(kind: .timing, points: 0, possiblePoints: 25),
                    try ScoreComponent(kind: .freshness, points: 0, possiblePoints: 25),
                    try ScoreComponent(kind: .continuity, points: 0, possiblePoints: 5)
                ],
                ruleVersion: Self.ruleVersion
            )
        }
        let weights: [(ScoreComponent.Kind, Int)] = [(.duration, 45), (.timing, 25), (.freshness, 25), (.continuity, 5)]

        let components = try weights.map { kind, possible in
            let ratio: Double
            switch kind {
            case .duration:
                let difference = record.sleepDuration - settings.desiredSleepDuration
                let limit = difference < 0 ? 4.0 * 60 * 60 : 4.5 * 60 * 60
                ratio = max(0, 1 - max(0, abs(difference) - 30 * 60) / (limit - 30 * 60))
            case .timing:
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
                let wakeMinutes = calendar.component(.hour, from: record.wakeTime) * 60
                    + calendar.component(.minute, from: record.wakeTime)
                let target = settings.standardWakeTime.minutesSinceMidnight
                let directDifference = abs(wakeMinutes - target)
                let circularDifference = min(directDifference, 24 * 60 - directDifference)
                ratio = max(0, 1 - Double(max(0, circularDifference - 15)) / 165)
            case .freshness:
                ratio = Double(record.freshnessValue) / 100
            case .continuity:
                ratio = max(0, 1 - Double(record.factors.awakeningCount ?? 0) / 10)
            }
            return try ScoreComponent(
                kind: kind,
                points: Int((Double(possible) * ratio).rounded()),
                possiblePoints: possible,
                exactPoints: Double(possible) * ratio
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
