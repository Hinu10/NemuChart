import Foundation

struct LifestyleAssociationService: Sendable {
    static let minimumSamplesPerGroup = 5

    func analyze(records: [SleepRecord]) -> [FactorAssociationResult] {
        LifestyleFactorKind.allCases.compactMap { factor in
            let classified = records.compactMap { record -> (Bool, Double)? in
                guard let exposed = classification(for: factor, record: record) else { return nil }
                return (exposed, Double(record.freshness.rawValue))
            }
            let exposed = classified.filter(\.0).map(\.1)
            let comparison = classified.filter { !$0.0 }.map(\.1)
            guard exposed.count >= Self.minimumSamplesPerGroup,
                  comparison.count >= Self.minimumSamplesPerGroup else { return nil }
            let difference = average(exposed) - average(comparison)
            let total = exposed.count + comparison.count
            let confidence: AnalysisConfidence = total >= 30 ? .moderate : .low
            return FactorAssociationResult(
                factor: factor,
                exposedCount: exposed.count,
                comparisonCount: comparison.count,
                freshnessDifference: difference,
                confidence: confidence
            )
        }
    }

    private func classification(for factor: LifestyleFactorKind, record: SleepRecord) -> Bool? {
        switch factor {
        case .alcohol: record.factors.consumedAlcohol
        case .caffeine: record.factors.consumedCaffeine
        case .nap: record.factors.napMinutes.map { $0 > 0 }
        case .smartphone:
            record.factors.smartphoneEndTime.map { record.bedTime.timeIntervalSince($0) >= 30 * 60 }
        }
    }

    private func average(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }
}

struct LongTermReportService: Sendable {
    static let minimumRecords = 14

    func report(records: [SleepRecord], days: Int, endingAt: Date = Date()) -> LongTermReport? {
        guard days == 30 || days == 90 else { return nil }
        let start = Calendar(identifier: .gregorian).date(byAdding: .day, value: -(days - 1), to: endingAt)!
        let selected = records.filter { $0.wakeTime >= start && $0.wakeTime <= endingAt }
        guard selected.count >= Self.minimumRecords else { return nil }

        let monthly = buckets(records: selected) { record in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
            let components = calendar.dateComponents([.year, .month], from: record.wakeTime)
            let id = String(format: "%04d-%02d", components.year!, components.month!)
            return (id, id)
        }
        let symbols = Calendar(identifier: .gregorian).shortWeekdaySymbols
        let weekdays = buckets(records: selected) { record in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
            let weekday = calendar.component(.weekday, from: record.wakeTime)
            return (String(weekday), symbols[weekday - 1])
        }.sorted { Int($0.id)! < Int($1.id)! }
        let weekdayValues = selected.filter { weekday(of: $0) != 1 && weekday(of: $0) != 7 }
        let weekendValues = selected.filter { weekday(of: $0) == 1 || weekday(of: $0) == 7 }
        return LongTermReport(
            requestedDays: days,
            recordCount: selected.count,
            monthly: monthly,
            weekdays: weekdays,
            weekdayFreshness: averageFreshness(weekdayValues),
            weekendFreshness: averageFreshness(weekendValues),
            timeZoneCount: Set(selected.map { $0.sleepDay.timeZoneIdentifier }).count
        )
    }

    private func buckets(
        records: [SleepRecord],
        key: (SleepRecord) -> (id: String, title: String)
    ) -> [LongTermBucket] {
        var grouped: [String: [SleepRecord]] = [:]
        for record in records { grouped[key(record).id, default: []].append(record) }
        var result: [LongTermBucket] = []
        for (id, values) in grouped {
            let totalDuration = values.reduce(0.0) { $0 + $1.sleepDuration }
            result.append(LongTermBucket(
                id: id,
                title: key(values[0]).title,
                recordCount: values.count,
                averageDuration: totalDuration / Double(values.count),
                averageFreshness: averageFreshness(values)!
            ))
        }
        return result.sorted { $0.id < $1.id }
    }

    private func weekday(of record: SleepRecord) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
        return calendar.component(.weekday, from: record.wakeTime)
    }

    private func averageFreshness(_ records: [SleepRecord]) -> Double? {
        guard !records.isEmpty else { return nil }
        return records.map { Double($0.freshness.rawValue) }.reduce(0, +) / Double(records.count)
    }
}

struct SleepDataExportService: Sendable {
    func json(records: [SleepRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(records.sorted { $0.sleepDay < $1.sleepDay })
    }

    func csv(records: [SleepRecord]) -> Data {
        let header = [
            "id", "sleepDay", "timeZone", "bedTime", "sleepStart", "wakeTime", "freshness",
            "isAllNighter", "awakeningCount", "snoozeCount", "secondSleepMinutes", "napMinutes", "consumedAlcohol",
            "consumedCaffeine", "smartphoneEndTime", "stress", "comfort", "reportedSnoring",
            "reportedBreathingPause", "createdAt", "updatedAt"
        ]
        let formatter = ISO8601DateFormatter()
        let rows = records.sorted { $0.sleepDay < $1.sleepDay }.map { record in
            let factors = record.factors
            return [
                record.id.uuidString, record.sleepDay.key, record.sleepDay.timeZoneIdentifier,
                formatter.string(from: record.bedTime), formatter.string(from: record.sleepStart),
                formatter.string(from: record.wakeTime), String(record.freshness.rawValue),
                String(record.isAllNighter), text(factors.awakeningCount), text(factors.snoozeCount), text(factors.secondSleepMinutes),
                text(factors.napMinutes), text(factors.consumedAlcohol), text(factors.consumedCaffeine),
                factors.smartphoneEndTime.map(formatter.string(from:)) ?? "", text(factors.stress?.rawValue),
                text(factors.comfort?.rawValue), text(factors.reportedSnoring), text(factors.reportedBreathingPause),
                formatter.string(from: record.createdAt), formatter.string(from: record.updatedAt)
            ].map(escape).joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n").data(using: .utf8)!
    }

    private func text<T>(_ value: T?) -> String { value.map(String.init(describing:)) ?? "" }
    private func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
