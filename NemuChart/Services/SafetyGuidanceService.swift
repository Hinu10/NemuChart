import Foundation

struct SafetyGuidance: Equatable, Sendable {
    let title: String
    let message: String
}

struct SafetyGuidanceService: Sendable {
    static let requiredConsecutiveVeryTiredRecords = 3
    static let redisplayInterval: TimeInterval = 14 * 24 * 60 * 60

    func guidance(records: [SleepRecord], dismissedAt: Date?, now: Date = Date()) -> SafetyGuidance? {
        if let dismissedAt, now.timeIntervalSince(dismissedAt) < Self.redisplayInterval { return nil }
        let latest = records.sorted { $0.sleepDay > $1.sleepDay }
        let recent = Array(latest.prefix(5))
        let persistentTiredness = latest.prefix(Self.requiredConsecutiveVeryTiredRecords).count == Self.requiredConsecutiveVeryTiredRecords
            && latest.prefix(Self.requiredConsecutiveVeryTiredRecords).allSatisfy({ $0.freshness == .veryTired })
        let repeatedBreathingReport = recent.filter { $0.factors.reportedBreathingPause == true }.count >= 2
        let repeatedSnoringReport = recent.filter { $0.factors.reportedSnoring == true }.count >= 3
        guard persistentTiredness || repeatedBreathingReport || repeatedSnoringReport else {
            return nil
        }
        return SafetyGuidance(
            title: String(localized: "睡眠について相談することも選べます"),
            message: String(localized: "強い眠気が続いて気になる場合は、無理をせず医療機関などへ相談することを検討してください。この案内は医療上の判断を示すものではありません。")
        )
    }
}
