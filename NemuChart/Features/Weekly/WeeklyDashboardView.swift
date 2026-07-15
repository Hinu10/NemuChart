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
        }
    }

    private func sleepChart(_ metrics: WeeklyMetrics) -> some View {
        let days = chartDays(metrics)
        return GroupBox("睡眠時間") {
            Chart(days) { day in
                BarMark(
                    x: .value("日", day.label),
                    y: .value("時間", day.hours ?? 0.12)
                )
                .foregroundStyle(day.hours == nil ? Color.secondary.opacity(0.35) : Color.indigo)
                .annotation(position: .top) {
                    Text(day.hours == nil ? "未" : String(format: "%.1f", day.hours!))
                        .font(.caption2)
                }
            }
            .chartYScale(domain: 0...12)
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("直近7日間の睡眠時間グラフ")
            .accessibilityValue(days.map { "\($0.label)は\($0.hours.map { String(format: "%.1f時間", $0) } ?? "記録なし")" }.joined(separator: "、"))
            Text("紫の棒は記録済み、「未」は記録のない日です。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metricGrid(_ metrics: WeeklyMetrics) -> some View {
        VStack(spacing: 12) {
            metric("平均睡眠時間", metrics.averageSleepDuration.map(durationText) ?? "—")
            metric("就床時刻のばらつき", metrics.bedTimeVariationMinutes.map { "約\(Int($0.rounded()))分" } ?? "—")
            metric("起床時刻のばらつき", metrics.wakeTimeVariationMinutes.map { "約\(Int($0.rounded()))分" } ?? "—")
            metric("平均スッキリ度", metrics.averageFreshness.map { String(format: "%.1f / 5", $0) } ?? "—")
            metric("スヌーズした割合", metrics.snoozeRate.map(percent) ?? "未入力")
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
            return ChartDay(key: key, label: date.formatted(.dateTime.weekday(.narrow)), hours: metrics.recordsByDay[key].map { $0.sleepDuration / 3600 })
        }
    }

    private func durationText(_ value: TimeInterval) -> String {
        let minutes = Int(value / 60)
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

private struct ChartDay: Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let hours: Double?
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
