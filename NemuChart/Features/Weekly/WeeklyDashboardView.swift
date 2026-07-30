import Charts
import SwiftUI

struct WeeklyDashboardView: View {
    let repository: any SleepRecordRepository
    let scoringService: any ScoringServiceProtocol
    let analysisService: WeeklyAnalysisService
    let settings: UserSettings
    @Environment(\.dismiss) private var dismiss
    @State private var metrics: WeeklyMetrics?
    @State private var estimate: ComfortableDurationEstimate?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let metrics {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            scoreHeader(metrics)
                            dailyScores(metrics)
                            scoreBreakdown(metrics)
                            sleepChart(metrics)
                            metricGrid(metrics)
                            confidenceCard(metrics.confidence)
                            comfortCard
                        }
                        .padding()
                    }
                } else {
                    ProgressView("週間データを集計しています")
                }
            }
            .navigationTitle("7日間の振り返り")
            .toolbar { Button("閉じる") { dismiss() } }
            .task { load() }
        }
        .alert("集計できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func scoreHeader(_ metrics: WeeklyMetrics) -> some View {
        GroupBox("週間スコア") {
            HStack(alignment: .firstTextBaseline) {
                Text(metrics.weeklyScore.map(String.init) ?? "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("点").foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(metrics.recordedDayCount) / 7日記録")
                    if let difference = metrics.previousWeekScoreDifference {
                        Label(difference > 0 ? "+\(difference)点" : "\(difference)点", systemImage: difference >= 0 ? "arrow.up" : "arrow.down")
                    } else {
                        Text("前週比較は準備中")
                    }
                }
                .font(.subheadline)
            }
            if let score = metrics.weeklyScore {
                Text(scoreQualityText(score))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sleepChart(_ metrics: WeeklyMetrics) -> some View {
        let days = chartDays(metrics)
        return GroupBox("睡眠時間") {
            Chart(days) { day in
                if let hours = day.hours {
                    BarMark(
                        x: .value("日", day.label),
                        yStart: .value("開始", 0),
                        yEnd: .value("夜間睡眠", hours)
                    )
                    .foregroundStyle(Color.teal)
                    if day.napHours > 0 {
                        BarMark(
                            x: .value("日", day.label),
                            yStart: .value("夜間睡眠", hours),
                            yEnd: .value("昼寝込み", hours + day.napHours)
                        )
                        .foregroundStyle(Color.orange)
                    }
                    BarMark(
                        x: .value("日", day.label),
                        yStart: .value("ラベル開始", hours + day.napHours),
                        yEnd: .value("ラベル終端", hours + day.napHours)
                    )
                    .foregroundStyle(.clear)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", hours + day.napHours))
                            .font(.caption2)
                    }
                } else {
                    BarMark(
                        x: .value("日", day.label),
                        y: .value("時間", 0.12)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .annotation(position: .top) {
                        Text("未")
                            .font(.caption2)
                    }
                }
            }
            .chartYScale(domain: 0...12)
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("直近7日間の睡眠時間グラフ")
            .accessibilityValue(days.map { day in
                if let hours = day.hours {
                    return "\(day.label)は夜間睡眠\(String(format: "%.1f時間", hours))、昼寝\(String(format: "%.1f時間", day.napHours))"
                }
                return "\(day.label)は記録なし"
            }.joined(separator: "、"))
            Text("青緑は夜間睡眠、オレンジは昼寝です。昼寝はグラフに上積みしますが、点数には加算しません。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func dailyScores(_ metrics: WeeklyMetrics) -> some View {
        let days = chartDays(metrics)
        return GroupBox("日付ごとのスコア") {
            VStack(spacing: 10) {
                ForEach(days) { day in
                    HStack {
                        Text(day.dateLabel)
                        Spacer()
                        Text(day.score.map { "\($0.total)点" } ?? "未記録")
                            .bold(day.score != nil)
                            .foregroundStyle(day.score == nil ? .secondary : .primary)
                    }
                    if day.id != days.last?.id { Divider() }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func metricGrid(_ metrics: WeeklyMetrics) -> some View {
        VStack(spacing: 12) {
            metric("平均睡眠時間", metrics.averageSleepDuration.map(durationText) ?? "—")
            metric("就床時刻のばらつき", metrics.bedTimeVariationMinutes.map { "約\(Int($0.rounded()))分" } ?? "—")
            metric("起床時刻のばらつき", metrics.wakeTimeVariationMinutes.map { "約\(Int($0.rounded()))分" } ?? "—")
            metric("平均スッキリ度", metrics.averageFreshness.map { String(format: "%.1f / 5", $0) } ?? "—")
            metric("スヌーズした割合", metrics.snoozeRate.map(percent) ?? "—")
            metric("睡眠時間目標に近い割合", metrics.sleepDurationGoalRate.map(percent) ?? "—")
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).bold() }
            .padding().background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func confidenceCard(_ confidence: ConfidenceAssessment) -> some View {
        GroupBox("分析信頼度：\(confidence.level.displayName)") {
            VStack(alignment: .leading, spacing: 8) {
                Text(confidence.reason)
                Text("任意項目の入力率 \(percent(confidence.optionalDataCompleteness))")
                    .font(.caption).foregroundStyle(.secondary)
                Text("表示は入力済みデータ内の傾向で、因果関係を示すものではありません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var comfortCard: some View {
        GroupBox("スッキリしやすい睡眠時間の傾向") {
            if let estimate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(estimate.lowerBoundMinutes / 60)時間\(estimate.lowerBoundMinutes % 60)分〜\(estimate.upperBoundMinutes / 60)時間\(estimate.upperBoundMinutes % 60)分")
                        .font(.headline)
                    Text(estimate.explanation)
                    Text("有効サンプル \(estimate.sampleCount)件 ・ 信頼度 \(estimate.confidence.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("推定には10件以上の記録と、十分なスッキリ度の入力が必要です。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() {
        do {
            let records = try repository.records()
            let endDay = try DateTimeService().sleepDay(for: Date(), timeZoneIdentifier: TimeZone.current.identifier)
            metrics = try analysisService.metrics(records: records, endDay: endDay, settings: settings, scoringService: scoringService)
            estimate = analysisService.comfortableDurationEstimate(records: records)
        } catch { errorMessage = error.localizedDescription }
    }

    private func chartDays(_ metrics: WeeklyMetrics) -> [ChartDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: metrics.endDay.timeZoneIdentifier) ?? .current
        let end = calendar.date(from: DateComponents(year: metrics.endDay.year, month: metrics.endDay.month, day: metrics.endDay.day))!
        return (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: end)!
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
            let record = metrics.recordsByDay[key]
            let score = record.flatMap { try? scoringService.score(record: $0, settings: settings) }
            return ChartDay(
                key: key,
                label: date.formatted(.dateTime.weekday(.narrow)),
                dateLabel: date.formatted(.dateTime.month().day().weekday(.abbreviated)),
                hours: record.map { $0.sleepDuration / 3600 },
                napHours: Double(record?.factors.napMinutes ?? 0) / 60,
                score: score
            )
        }
    }

    private func scoreBreakdown(_ metrics: WeeklyMetrics) -> some View {
        let days = chartDays(metrics).filter { $0.score != nil }
        return GroupBox("点数の内訳") {
            if days.isEmpty {
                Text("記録がある日に、睡眠時間・起床時刻・スッキリ度などの内訳を表示します。")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(day.dateLabel).font(.headline)
                                Spacer()
                                Text("\(day.score?.total ?? 0)点").bold()
                            }
                            ForEach(day.score?.components ?? [], id: \.kind) { component in
                                HStack {
                                    Text(component.kind.displayName)
                                    Spacer()
                                    Text("\(component.points) / \(component.possiblePoints)")
                                        .monospacedDigit()
                                }
                                .font(.subheadline)
                                ProgressView(value: Double(component.points), total: Double(component.possiblePoints))
                            }
                        }
                        if day.id != days.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func durationText(_ value: TimeInterval) -> String {
        let minutes = Int(value / 60)
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func scoreQualityText(_ score: Int) -> String {
        switch score {
        case 85...100: "85点以上はとても良い目安です。"
        case 70..<85: "70点以上は良い目安です。"
        case 50..<70: "50〜69点は改善の余地があります。"
        default: "49点以下は休息を優先したい状態です。"
        }
    }
}

private struct ChartDay: Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let dateLabel: String
    let hours: Double?
    let napHours: Double
    let score: DailySleepScore?
}

private extension ScoreComponent.Kind {
    var displayName: String {
        switch self {
        case .duration: "睡眠時間"
        case .timing: "起床時刻"
        case .freshness: "スッキリ度"
        case .continuity: "睡眠の分断"
        }
    }
}

extension AnalysisConfidence {
    var displayName: String {
        switch self {
        case .insufficient: "準備中"
        case .low: "仮の傾向"
        case .moderate: "見えてきた"
        case .high: "比較的安定"
        }
    }
}
