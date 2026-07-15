import Foundation

struct WeeklyAnalysisService: Sendable {
    static let minimumTrendRecords = 3
    static let moderateConfidenceRecords = 5
    static let highConfidenceRecords = 7
    static let minimumComfortEstimateRecords = 10

    func metrics(
        records: [SleepRecord],
        endDay: SleepDay,
        settings: UserSettings,
        scoringService: any ScoringServiceProtocol
    ) throws -> WeeklyMetrics {
        let days = try dayKeys(endingAt: endDay, count: 7)
        let startDay = try shifted(endDay, by: -6)
        let current = deduplicated(records.filter { days.contains($0.sleepDay.key) })
        let previousDays = try dayKeys(endingBefore: startDay.key, timeZoneIdentifier: endDay.timeZoneIdentifier, count: 7)
        let previous = deduplicated(records.filter { previousDays.contains($0.sleepDay.key) })
        let scores = try current.map { try scoringService.score(record: $0, settings: settings).total }
        let previousScores = try previous.map { try scoringService.score(record: $0, settings: settings).total }
        let weeklyScore = average(scores).map { Int($0.rounded()) }
        let previousScore = average(previousScores).map { Int($0.rounded()) }
        let optionalCompleteness = completeness(of: current)
        let confidence = confidence(recordCount: current.count, completeness: optionalCompleteness)

        return WeeklyMetrics(
            startDay: startDay,
            endDay: endDay,
            recordsByDay: Dictionary(uniqueKeysWithValues: current.map { ($0.sleepDay.key, $0) }),
            recordedDayCount: current.count,
            averageSleepDuration: average(current.map(\.sleepDuration)),
            bedTimeVariationMinutes: variation(of: current.map(\.bedTime), timeZoneIdentifier: endDay.timeZoneIdentifier, treatsEarlyMorningAsNextDay: true),
            wakeTimeVariationMinutes: variation(of: current.map(\.wakeTime), timeZoneIdentifier: endDay.timeZoneIdentifier, treatsEarlyMorningAsNextDay: false),
            averageFreshness: average(current.map { Double($0.freshness.rawValue) }),
            snoozeRate: rate(values: current.compactMap(\.factors.snoozeCount)) { $0 > 0 },
            sleepDurationGoalRate: rate(values: current.map(\.sleepDuration)) {
                abs($0 - settings.desiredSleepDuration) <= 30 * 60
            },
            weeklyScore: weeklyScore,
            previousWeekScoreDifference: weeklyScore.flatMap { current in previousScore.map { current - $0 } },
            confidence: confidence
        )
    }

    func comfortableDurationEstimate(records: [SleepRecord]) -> ComfortableDurationEstimate? {
        guard records.count >= Self.minimumComfortEstimateRecords else { return nil }
        let minutes = records.map { Int($0.sleepDuration / 60) }.sorted()
        let q1 = percentile(minutes, 0.25)
        let q3 = percentile(minutes, 0.75)
        let iqr = max(30, q3 - q1)
        let filtered = records.filter {
            let value = Int($0.sleepDuration / 60)
            return value >= q1 - Int(Double(iqr) * 1.5) && value <= q3 + Int(Double(iqr) * 1.5)
        }
        let groups = Dictionary(grouping: filtered) { Int($0.sleepDuration / 60) / 30 * 30 }
        guard let best = groups.max(by: { lhs, rhs in
            let left = average(lhs.value.map { Double($0.freshness.rawValue) }) ?? 0
            let right = average(rhs.value.map { Double($0.freshness.rawValue) }) ?? 0
            if left == right { return lhs.value.count < rhs.value.count }
            return left < right
        }) else { return nil }
        let freshness = average(best.value.map { Double($0.freshness.rawValue) }) ?? 0
        guard freshness >= 3 else { return nil }
        let confidence: AnalysisConfidence = filtered.count >= 20 ? .high : filtered.count >= 14 ? .moderate : .low
        return ComfortableDurationEstimate(
            lowerBoundMinutes: best.key,
            upperBoundMinutes: best.key + 30,
            sampleCount: filtered.count,
            confidence: confidence,
            explanation: String(localized: "入力済み記録では、この範囲でスッキリ度が高い傾向の可能性があります。")
        )
    }

    private func confidence(recordCount: Int, completeness: Double) -> ConfidenceAssessment {
        let level: AnalysisConfidence
        let reason: String
        if recordCount < Self.minimumTrendRecords {
            level = .insufficient
            reason = String(localized: "準備中：傾向には3日以上の記録が必要です。")
        } else if recordCount < Self.moderateConfidenceRecords || completeness < 0.2 {
            level = .low
            reason = String(localized: "仮の傾向：記録数または任意項目がまだ少なめです。")
        } else if recordCount < Self.highConfidenceRecords || completeness < 0.5 {
            level = .moderate
            reason = String(localized: "見えてきた：複数日の記録から参考になる傾向を表示しています。")
        } else {
            level = .high
            reason = String(localized: "比較的安定：7日分と十分な入力がありますが、因果関係を示すものではありません。")
        }
        return ConfidenceAssessment(level: level, reason: reason, recordCount: recordCount, optionalDataCompleteness: completeness)
    }

    private func completeness(of records: [SleepRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        let count = records.reduce(0) { result, record in
            let factors: [Any?] = [record.factors.awakeningCount, record.factors.snoozeCount,
                record.factors.secondSleepMinutes, record.factors.napMinutes, record.factors.consumedAlcohol,
                record.factors.consumedCaffeine, record.factors.smartphoneEndTime, record.factors.stress, record.factors.comfort,
                record.factors.reportedSnoring, record.factors.reportedBreathingPause]
            return result + factors.compactMap { $0 }.count
        }
        return Double(count) / Double(records.count * 11)
    }

    private func variation(of dates: [Date], timeZoneIdentifier: String, treatsEarlyMorningAsNextDay: Bool) -> Double? {
        guard dates.count >= 2 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let values = dates.map { date -> Double in
            var minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
            if treatsEarlyMorningAsNextDay && minutes < 12 * 60 { minutes += 24 * 60 }
            return Double(minutes)
        }
        let mean = average(values)!
        return sqrt(values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count))
    }

    private func rate<T>(values: [T], predicate: (T) -> Bool) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.filter(predicate).count) / Double(values.count)
    }

    private func average<T: BinaryInteger>(_ values: [T]) -> Double? { average(values.map(Double.init)) }
    private func average(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private func dayKeys(endingAt day: SleepDay, count: Int) throws -> Set<String> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: day.timeZoneIdentifier)!
        let end = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        return Set((0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: end)!
            return Self.key(date, calendar: calendar)
        })
    }

    private func shifted(_ day: SleepDay, by offset: Int) throws -> SleepDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: day.timeZoneIdentifier)!
        let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        return try sleepDay(
            from: Self.key(calendar.date(byAdding: .day, value: offset, to: date)!, calendar: calendar),
            timeZoneIdentifier: day.timeZoneIdentifier
        )
    }

    private func deduplicated(_ records: [SleepRecord]) -> [SleepRecord] {
        Dictionary(grouping: records, by: { $0.sleepDay.key }).compactMap { _, values in
            values.max(by: { $0.updatedAt < $1.updatedAt })
        }
    }

    private func dayKeys(endingBefore key: String, timeZoneIdentifier: String, count: Int) throws -> Set<String> {
        let day = try sleepDay(from: key, timeZoneIdentifier: timeZoneIdentifier)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        let start = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        return Set((1...count).map { Self.key(calendar.date(byAdding: .day, value: -$0, to: start)!, calendar: calendar) })
    }

    private func sleepDay(from key: String, timeZoneIdentifier: String) throws -> SleepDay {
        let values = key.split(separator: "-").compactMap { Int($0) }
        return try SleepDay(year: values[0], month: values[1], day: values[2], timeZoneIdentifier: timeZoneIdentifier)
    }

    private static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func percentile(_ sorted: [Int], _ fraction: Double) -> Int {
        sorted[Int((Double(sorted.count - 1) * fraction).rounded())]
    }
}
