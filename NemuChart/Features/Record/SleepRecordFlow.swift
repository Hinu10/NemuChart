import SwiftUI

struct SleepRecordFlow: View {
    let repository: any SleepRecordRepository
    let scoringService: any ScoringServiceProtocol
    let feedbackService: SheepFeedbackService
    let goalRepository: (any SleepGoalRepository)?
    let preferences: AppPreferencesStore?
    let notificationService: (any LocalNotificationServiceProtocol)?
    let settings: UserSettings
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SleepRecordDraft
    @State private var phase = Phase.form
    @State private var pendingRecord: SleepRecord?
    @State private var savedRecord: SleepRecord?
    @State private var score: DailySleepScore?
    @State private var comparison: ScoreComparison = .init(previous: nil, recentAverage: nil)
    @State private var isSaving = false
    @State private var growthPointsEarned = 0
    @State private var growthBefore = 0
    @State private var growthAfter = 0
    @State private var earning: SheepGrowthService.Earning?
    @State private var newlyUnlocked: [SheepCollectible] = []
    @State private var showingGoal = false
    @State private var errorMessage: String?
    @State private var duplicate: SleepRecord?

    init(
        repository: any SleepRecordRepository,
        scoringService: any ScoringServiceProtocol,
        settings: UserSettings,
        feedbackService: SheepFeedbackService = SheepFeedbackService(),
        goalRepository: (any SleepGoalRepository)? = nil,
        preferences: AppPreferencesStore? = nil,
        notificationService: (any LocalNotificationServiceProtocol)? = nil,
        initialRecord: SleepRecord? = nil,
        initialDraft: SleepRecordDraft? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.scoringService = scoringService
        self.settings = settings
        self.feedbackService = feedbackService
        self.goalRepository = goalRepository
        self.preferences = preferences
        self.notificationService = notificationService
        self.onSaved = onSaved
        _draft = State(initialValue: initialRecord.map(SleepRecordDraft.init(record:)) ?? initialDraft ?? SleepRecordDraft())
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .form: form
                case .confirmation: confirmation
                case .result:
                    if let score, let savedRecord {
                        DailyScoreView(
                            score: score,
                            record: savedRecord,
                            comparison: comparison,
                            feedback: feedbackService.feedback(for: score),
                            growthPointsEarned: growthPointsEarned,
                            growthBefore: growthBefore,
                            growthAfter: growthAfter,
                            earning: earning,
                            newlyUnlocked: newlyUnlocked,
                            onSetGoal: goalRepository == nil ? nil : { showingGoal = true }
                        )
                    }
                }
            }
            .navigationTitle(phase.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $showingGoal) {
            if let goalRepository, let preferences {
                TonightGoalView(
                    settings: settings,
                    records: (try? repository.records()) ?? [],
                    repository: goalRepository,
                    preferences: preferences,
                    notificationService: notificationService
                ) { dismiss() }
            }
        }
        .alert("入力を確認してください", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        .alert("同じ睡眠日の記録があります", isPresented: Binding(
            get: { duplicate != nil },
            set: { if !$0 { duplicate = nil } }
        )) {
            Button("既存の記録を編集") {
                if let duplicate { draft = SleepRecordDraft(record: duplicate) }
                duplicate = nil
                phase = .form
            }
            Button("キャンセル", role: .cancel) { duplicate = nil }
        } message: {
            Text("上書きはせず、既存記録の編集へ切り替えられます。")
        }
    }

    private var form: some View {
        Form {
            Section("記録の種類") {
                Picker("記録の種類", selection: $draft.inputKind) {
                    Text("睡眠した").tag(SleepRecordInputKind.slept)
                    Text("徹夜した").tag(SleepRecordInputKind.allNighter)
                }
                .pickerStyle(.segmented)
                if draft.inputKind == .allNighter {
                    DatePicker("対象日", selection: $draft.recordDate, displayedComponents: .date)
                    Text("睡眠なしとして0時間で記録します。架空の時刻入力は必要ありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if draft.inputKind == .slept {
                Section("必須項目") {
                    DatePicker("記録日（起きた日）", selection: $draft.recordDate, displayedComponents: .date)
                    DatePicker("起床時刻", selection: $draft.wakeTime, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("wakeDateTimePicker")
                    DatePicker("寝た時刻", selection: $draft.sleepClock, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("sleepDateTimePicker")
                    Text("正確な時刻を覚えていない場合は、記憶している範囲で大丈夫です。")
                        .font(.footnote).foregroundStyle(.secondary)
                    DisclosureGroup("日付を手動で調整") {
                        Toggle("寝た日付を指定", isOn: $draft.manuallyAdjustDates)
                        if draft.manuallyAdjustDates {
                            DatePicker("寝た日時", selection: $draft.sleepClock)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("起床時のスッキリ度：\(draft.freshnessRate) / 100")
                        Slider(value: Binding(
                            get: { Double(draft.freshnessRate) },
                            set: { draft.freshnessRate = Int($0) }
                        ), in: 0...100, step: 5)
                        Text("0 まったくスッキリしていない · 50 普通 · 100 とてもスッキリ")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("任意の睡眠詳細・生活要因") {
                    OptionalIntPicker(title: "中途覚醒", value: $draft.awakeningCount, range: 0...10, unit: "回")
                    OptionalIntPicker(title: "スヌーズ", value: $draft.snoozeCount, range: 0...10, unit: "回")
                    OptionalIntPicker(title: "昨日の昼寝", value: $draft.napMinutes, values: [0, 10, 20, 30, 45, 60, 90, 120], unit: "分")
                    OptionalBoolPicker(title: "飲酒", value: $draft.consumedAlcohol, trueLabel: "あり", falseLabel: "なし")
                    OptionalBoolPicker(title: "カフェイン", value: $draft.consumedCaffeine, trueLabel: "摂取した", falseLabel: "摂取していない")
                    if let smartphoneEndTime = draft.smartphoneEndTime {
                        DatePicker("スマートフォン終了日時", selection: Binding(
                            get: { smartphoneEndTime },
                            set: { draft.smartphoneEndTime = $0 }
                        ))
                        .accessibilityIdentifier("smartphoneEndDateTimePicker")
                        Button("スマートフォン終了日時を未入力に戻す") { draft.smartphoneEndTime = nil }
                    } else {
                        Button("スマートフォン終了日時を入力") { draft.smartphoneEndTime = draft.sleepClock }
                            .accessibilityIdentifier("smartphoneEndTimeEntryButton")
                    }
                    OptionalRatingPicker(title: "ストレス", value: $draft.stress)
                    OptionalRatingPicker(title: "快適さ", value: $draft.comfort)
                    OptionalBoolPicker(title: "いびきの指摘", value: $draft.reportedSnoring, trueLabel: "指摘あり", falseLabel: "なし")
                    OptionalBoolPicker(title: "呼吸が止まったとの指摘", value: $draft.reportedBreathingPause, trueLabel: "指摘あり", falseLabel: "なし")
                    Text("選ばなかった項目は「未入力」として保存され、「なし」や0回とは区別されます。分析では未入力の日を除いて比較します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("入力内容を確認") { validate() }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("reviewSleepRecord")
            }
        }
    }

    private var confirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let record = pendingRecord {
                    GroupBox("基本情報") {
                        LabeledContent("睡眠日", value: record.sleepDay.key)
                        if record.isAllNighter {
                            LabeledContent("記録", value: "徹夜（睡眠なし）")
                            LabeledContent("睡眠時間", value: "0時間")
                        } else {
                            LabeledContent("ベッド", value: record.bedTime.formatted(date: .omitted, time: .shortened))
                            LabeledContent("入眠", value: record.sleepStart.formatted(date: .omitted, time: .shortened))
                            LabeledContent("起床", value: record.wakeTime.formatted(date: .omitted, time: .shortened))
                            LabeledContent("睡眠時間", value: durationText(record.sleepDuration))
                            LabeledContent("スッキリ度", value: "\(record.freshnessValue) / 100")
                        }
                    }
                    if !record.isAllNighter {
                        Text("時刻の順序や睡眠時間を確認してください。極端な値は自動補正せず、前の画面で修正できます。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("保存する") { save(record) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(isSaving)
                        .accessibilityIdentifier("saveSleepRecord")
                        .accessibilityHint("確認した睡眠記録を端末内に保存します")
                    Button("入力に戻る") { phase = .form }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("backToSleepRecordForm")
                }
            }
            .padding()
        }
    }

    private func validate() {
        do {
            pendingRecord = try draft.makeRecord()
            phase = .confirmation
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ record: SleepRecord) {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let oldRecords = try repository.records()
            let oldScores = try oldRecords.map { try scoringService.score(record: $0, settings: settings) }
            let goals = try goalRepository?.goals() ?? []
            let growthService = SheepGrowthService()
            let weeklyIDs = Array(preferences?.load().rewardedWeeklyGoalIDs ?? [])
            growthBefore = growthService.summary(earnings: growthService.earnings(records: oldRecords, scores: oldScores, goals: goals), completedWeeklyGoalIDs: weeklyIDs).points.value
            switch try repository.save(record) {
            case .created(let saved):
                savedRecord = saved
                score = try scoringService.score(record: saved, settings: settings)
                comparison = try makeComparison(for: saved)
                phase = .result
                refreshGrowth(saved: saved, service: growthService, goals: goals, weeklyIDs: weeklyIDs)
                onSaved()
            case .updated(let saved):
                savedRecord = saved
                score = try scoringService.score(record: saved, settings: settings)
                comparison = try makeComparison(for: saved)
                phase = .result
                refreshGrowth(saved: saved, service: growthService, goals: goals, weeklyIDs: weeklyIDs)
                onSaved()
            case .duplicate(let existing):
                duplicate = existing
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshGrowth(saved: SleepRecord, service: SheepGrowthService, goals: [SleepGoal], weeklyIDs: [UUID]) {
        guard let records = try? repository.records(),
              let scores = try? records.map({ try scoringService.score(record: $0, settings: settings) }) else { return }
        let earnings = service.earnings(records: records, scores: scores, goals: goals)
        earning = earnings.first { $0.recordID == saved.id }
        if var data = preferences?.load() {
            data.growthEarnings = Dictionary(uniqueKeysWithValues: earnings.map { ($0.recordID, $0) })
            try? preferences?.save(data)
        }
        growthAfter = service.summary(earnings: earnings, completedWeeklyGoalIDs: weeklyIDs).points.value
        growthPointsEarned = max(0, growthAfter - growthBefore)
        let alreadyUnlocked = preferences?.load().unlockedContentIDs ?? []
        newlyUnlocked = SheepCollectible.all.filter {
            growthAfter >= $0.requiredGrowth && !alreadyUnlocked.contains($0.id)
        }
    }

    private func makeComparison(for record: SleepRecord) throws -> ScoreComparison {
        let others = try repository.records()
            .filter { $0.id != record.id && $0.sleepDay < record.sleepDay }
        let scores = try others.prefix(7).map { try scoringService.score(record: $0, settings: settings).total }
        return ScoreComparison(
            previous: scores.first,
            recentAverage: scores.count >= 2 ? Double(scores.reduce(0, +)) / Double(scores.count) : nil
        )
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
}

private enum Phase {
    case form, confirmation, result
    var title: String {
        switch self {
        case .form: "睡眠を記録"
        case .confirmation: "入力内容の確認"
        case .result: "今日の結果"
        }
    }
}

private struct OptionalIntPicker: View {
    let title: String
    @Binding var value: Int?
    let values: [Int]
    let unit: String

    init(title: String, value: Binding<Int?>, range: ClosedRange<Int>, unit: String) {
        self.title = title; _value = value; values = Array(range); self.unit = unit
    }
    init(title: String, value: Binding<Int?>, values: [Int], unit: String) {
        self.title = title; _value = value; self.values = values; self.unit = unit
    }

    var body: some View {
        Picker(title, selection: $value) {
            Text("未入力").tag(Int?.none)
            ForEach(values, id: \.self) { Text("\($0)\(unit)").tag(Int?.some($0)) }
        }
    }
}

private struct OptionalBoolPicker: View {
    let title: String
    @Binding var value: Bool?
    let trueLabel: String
    let falseLabel: String
    var body: some View {
        Picker(title, selection: $value) {
            Text("未入力").tag(Bool?.none)
            Text(falseLabel).tag(Bool?.some(false))
            Text(trueLabel).tag(Bool?.some(true))
        }
    }
}

private struct OptionalRatingPicker: View {
    let title: String
    @Binding var value: Rating?
    var body: some View {
        Picker(title, selection: $value) {
            Text("未入力").tag(Rating?.none)
            ForEach(Rating.allCases, id: \.self) { Text($0.displayName).tag(Rating?.some($0)) }
        }
    }
}

extension Freshness {
    var displayName: String {
        switch self {
        case .veryTired: "とても重い"
        case .tired: "少し重い"
        case .neutral: "ふつう"
        case .refreshed: "スッキリ"
        case .veryRefreshed: "とてもスッキリ"
        }
    }
}

extension Rating {
    var displayName: String {
        switch self {
        case .veryLow: "とても低い"
        case .low: "低い"
        case .medium: "ふつう"
        case .high: "高い"
        case .veryHigh: "とても高い"
        }
    }
}
