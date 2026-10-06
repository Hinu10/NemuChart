import Foundation

struct LifestyleAssociationService: Sendable {
    static let minimumSamplesPerGroup = 5

    func analyze(records: [SleepRecord]) -> [FactorAssociationResult] {
        LifestyleFactorKind.allCases.compactMap { factor in
            let classified = records.compactMap { record -> (Bool, Double)? in
                guard let exposed = classification(for: factor, record: record) else { return nil }
                return (exposed, Double(record.freshnessValue))
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
        return records.map { Double($0.freshnessValue) }.reduce(0, +) / Double(records.count)
    }
}

/// CSV と JSON は同じ列・同じキー名・同じ順番で書き出す。空欄（未入力）と false / 0 は区別する。
/// 日時は記録したタイムゾーンの時刻（例: 2026-10-06T07:00:00+09:00）で書き出す。
struct SleepDataExportService: Sendable {
    enum Value: Equatable {
        case text(String)
        case number(Int)
        case flag(Bool)
        case date(Date, TimeZone)
        case missing
    }

    static let columns = [
        "記録ID", "睡眠日", "タイムゾーン", "就床日時", "入眠日時", "起床日時", "スッキリ度(0-100)",
        "徹夜", "中途覚醒(回)", "スヌーズ(回)", "昼寝(分)", "飲酒",
        "カフェイン", "ストレス(1-5)", "快適さ(1-5)", "いびきの指摘",
        "呼吸停止の指摘", "作成日時", "更新日時"
    ]

    /// 書き出す日付入りのファイル名。拡張子を付けないと保存先によって .txt になる。
    static func fileName(extension ext: String, on date: Date = Date()) -> String {
        "nemuchart-sleep-records-\(date.formatted(.iso8601.year().month().day())).\(ext)"
    }

    func rows(records: [SleepRecord]) -> [[Value]] {
        records.sorted { $0.sleepDay < $1.sleepDay }.map { record in
            let factors = record.factors
            let timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
            func date(_ value: Date) -> Value { .date(value, timeZone) }
            func number(_ value: Int?) -> Value { value.map(Value.number) ?? .missing }
            func flag(_ value: Bool?) -> Value { value.map(Value.flag) ?? .missing }
            return [
                .text(record.id.uuidString), .text(record.sleepDay.key), .text(record.sleepDay.timeZoneIdentifier),
                date(record.bedTime), date(record.sleepStart), date(record.wakeTime), .number(record.freshnessValue),
                .flag(record.isAllNighter), number(factors.awakeningCount), number(factors.snoozeCount),
                number(factors.napMinutes), flag(factors.consumedAlcohol),
                flag(factors.consumedCaffeine),
                number(factors.stress?.rawValue), number(factors.comfort?.rawValue), flag(factors.reportedSnoring),
                flag(factors.reportedBreathingPause), date(record.createdAt), date(record.updatedAt)
            ]
        }
    }

    func json(records: [SleepRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(rows(records: records).map(JSONRow.init))
    }

    func csv(records: [SleepRecord]) -> Data {
        let lines = rows(records: records).map { $0.map { escape(text($0)) }.joined(separator: ",") }
        return ([Self.columns.joined(separator: ",")] + lines).joined(separator: "\n").data(using: .utf8)!
    }

    private func text(_ value: Value) -> String {
        switch value {
        case .text(let text): text
        case .number(let number): String(number)
        case .flag(let flag): String(flag)
        case .date(let date, let timeZone): Self.format(date, in: timeZone)
        case .missing: ""
        }
    }

    fileprivate static func format(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// 列の順番どおりにキーを並べ、未入力は null にする。
    private struct JSONRow: Encodable {
        let values: [Value]

        struct Key: CodingKey {
            let stringValue: String
            init(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            for (column, value) in zip(SleepDataExportService.columns, values) {
                let key = Key(stringValue: column)
                switch value {
                case .text(let text): try container.encode(text, forKey: key)
                case .number(let number): try container.encode(number, forKey: key)
                case .flag(let flag): try container.encode(flag, forKey: key)
                case .date(let date, let timeZone): try container.encode(SleepDataExportService.format(date, in: timeZone), forKey: key)
                case .missing: try container.encodeNil(forKey: key)
                }
            }
        }
    }
}
