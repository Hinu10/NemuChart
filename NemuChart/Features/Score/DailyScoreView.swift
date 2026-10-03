import SwiftUI

struct ScoreComparison {
    let previous: Int?
    let recentAverage: Double?
}

struct DailyScoreView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let score: DailySleepScore
    let record: SleepRecord
    let comparison: ScoreComparison
    var feedback: SheepFeedback?
    var growthPointsEarned: Int = 0
    var growthBefore: Int = 0
    var growthAfter: Int = 0
    var earning: SheepGrowthService.Earning?
    var newlyUnlocked: [SheepCollectible] = []
    var onSetGoal: (() -> Void)?
    @State private var showingGrowth = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if dynamicTypeSize.isAccessibilitySize {
                    Text("日次睡眠スコア \(score.total)点 / 100点")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("dailyScoreSummary")
                } else {
                    ZStack {
                        Circle().stroke(.indigo.opacity(0.15), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: Double(score.total) / 100)
                            .stroke(.indigo, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack {
                            Text("\(score.total)").font(.system(size: 52, weight: .bold, design: .rounded))
                            Text("100点中").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 190, height: 190)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("日次睡眠スコア \(score.total)点")
                    .accessibilityIdentifier("dailyScoreSummary")
                }

                GroupBox("点数の目安") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(scoreQualityText(score.total))
                            .font(.headline)
                        Text("85点以上: とても良い / 70〜84点: 良い / 50〜69点: 見直しの余地あり / 49点以下: 休息を優先")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)

                GroupBox("内訳") {
                    ForEach(score.components, id: \.kind) { component in
                        LabeledContent(component.kind.displayName, value: String(format: "%.1f / %d", component.exactPoints, component.possiblePoints))
                    }
                }
                .frame(maxWidth: .infinity)

                GroupBox("比較") {
                    if let previous = comparison.previous {
                        LabeledContent("前回との差", value: signed(score.total - previous))
                    } else {
                        Text("前回の記録がないため、差分はまだ表示しません。")
                    }
                    if let average = comparison.recentAverage {
                        LabeledContent("直近平均との差", value: signed(score.total - Int(average.rounded())))
                    } else {
                        Text("平均には過去2件以上の記録が必要です。")
                    }
                }
                .frame(maxWidth: .infinity)

                if let feedback {
                    GroupBox("羊からのひとこと") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(feedback.status).font(.headline)
                            Text(feedback.positivePoint)
                            if let suggestion = feedback.suggestion {
                                Label(suggestion, systemImage: "lightbulb")
                            }
                            Text(feedback.closing).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("羊の成長") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("+\(growthPointsEarned) 成長！", systemImage: "sparkles")
                            .font(.title2.bold())
                            .scaleEffect(showingGrowth ? 1 : 0.8)
                            .opacity(showingGrowth ? 1 : 0)
                        if let earning {
                            LabeledContent("記録", value: "+\(earning.recordPoints)")
                            LabeledContent("睡眠スコア", value: "+\(earning.scorePoints)")
                            if earning.streakPoints > 0 { LabeledContent("連続記録", value: "+\(earning.streakPoints)") }
                            if earning.tonightPoints > 0 { LabeledContent("今夜の目標", value: "+\(earning.tonightPoints)") }
                        }
                        Text("合計成長値  \(growthBefore) → \(growthAfter)")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)

                ForEach(newlyUnlocked) { item in
                    GroupBox("新しいものが増えました！") {
                        Label("『\(item.name)』をアンロックしました", systemImage: item.symbol)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if let onSetGoal {
                    Button("今夜の目標を設定する", action: onSetGoal)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                Text("このスコアは入力内容と個人目標を比べた参考値で、医療上の評価ではありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(duration: 1.2)) { showingGrowth = true }
        }
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)点" : "\(value)点" }

    private func scoreQualityText(_ score: Int) -> String {
        switch score {
        case 85...100: "とても良い目安です"
        case 70..<85: "良い目安です"
        case 50..<70: "見直しの余地があります"
        default: "休息を優先したい状態です"
        }
    }
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
