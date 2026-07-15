import Foundation

struct SheepFeedbackService: Sendable {
    func feedback(for score: DailySleepScore) -> SheepFeedback {
        let ordered = score.components.sorted {
            normalized($0) == normalized($1)
                ? priority($0.kind) < priority($1.kind)
                : normalized($0) > normalized($1)
        }
        let best = ordered.first?.kind
        let improvement = ordered.last.flatMap { normalized($0) < 0.8 ? $0.kind : nil }

        return SheepFeedback(
            status: statusText(score.total),
            positivePoint: positiveText(best),
            suggestion: improvement.map(suggestionText),
            closing: score.total < 50
                ? String(localized: "記録できたことが、次の気づきにつながるよ。今日も教えてくれてありがとう。")
                : String(localized: "今日の記録もありがとう。無理のないペースで続けよう。")
        )
    }

    private func normalized(_ component: ScoreComponent) -> Double {
        Double(component.points) / Double(component.possiblePoints)
    }

    private func priority(_ kind: ScoreComponent.Kind) -> Int {
        switch kind {
        case .duration: 0
        case .timing: 1
        case .freshness: 2
        case .continuity: 3
        }
    }

    private func statusText(_ score: Int) -> String {
        switch score {
        case 80...: String(localized: "穏やかなリズムで過ごせたみたいだね。")
        case 55...: String(localized: "今日の状態を一緒に振り返ってみよう。")
        default: String(localized: "少し休息を大切にしたい日かもしれないね。")
        }
    }

    private func positiveText(_ kind: ScoreComponent.Kind?) -> String {
        switch kind {
        case .duration: String(localized: "睡眠時間は、目標に近づけられていたよ。")
        case .timing: String(localized: "起きる時刻のリズムが良かったよ。")
        case .freshness: String(localized: "起きたときの感覚を丁寧に記録できたね。")
        case .continuity: String(localized: "まとまった休息を取れた可能性があるね。")
        case nil: String(localized: "今日の睡眠を記録できたことが良かったよ。")
        }
    }

    private func suggestionText(_ kind: ScoreComponent.Kind) -> String {
        switch kind {
        case .duration: String(localized: "今夜は、希望する睡眠時間に少し近づける範囲で予定を整えてみよう。")
        case .timing: String(localized: "明日は、いつもの起床時刻をひとつの目安にしてみよう。")
        case .freshness: String(localized: "今夜は、眠る前にゆっくり過ごす時間を少し作ってみよう。")
        case .continuity: String(localized: "途中で目が覚めても責めず、休みやすい環境をひとつ整えてみよう。")
        }
    }
}
