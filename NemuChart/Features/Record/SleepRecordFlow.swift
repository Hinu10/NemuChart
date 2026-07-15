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
    @State private var showingGoal = false
    @State private var errorMessage: String?
    @State private var duplicate: SleepRecord?
    @State private var optionalExpanded = false

    init(
        repository: any SleepRecordRepository,
        scoringService: any ScoringServiceProtocol,
        settings: UserSettings,
        feedbackService: SheepFeedbackService = SheepFeedbackService(),
        goalRepository: (any SleepGoalRepository)? = nil,
        preferences: AppPreferencesStore? = nil,
        notificationService: (any LocalNotificationServiceProtocol)? = nil,
        initialRecord: SleepRecord? = nil,
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
        _draft = State(initialValue: initialRecord.map(SleepRecordDraft.init(record:)) ?? SleepRecordDraft())
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
            Section("必須項目（4項目）") {
                DatePicker("起床日時", selection: $draft.wakeTime)
                DatePicker("ベッド時刻", selection: $draft.bedClock, displayedComponents: .hourAndMinute)
                Picker("入眠の入力方法", selection: $draft.sleepStartInputMode) {
                    Text("入眠時刻").tag(SleepStartInputMode.clockTime)
                    Text("入眠までの時間").tag(SleepStartInputMode.latency)
                }
                .pickerStyle(.segmented)
                if draft.sleepStartInputMode == .clockTime {
                    DatePicker("入眠時刻", selection: $draft.sleepClock, displayedComponents: .hourAndMinute)
                } else {
                    Stepper("入眠まで \(draft.latencyMinutes)分", value: $draft.latencyMinutes, in: 0...240, step: 5)
                }
                Picker("起床時のスッキリ度", selection: $draft.freshness) {
                    ForEach(Freshness.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
            }

            Section {
                DisclosureGroup("任意の睡眠詳細・生活要因", isExpanded: $optionalExpanded) {
                    OptionalIntPicker(title: "中途覚醒", value: $draft.awakeningCount, range: 0...10, unit: "回")
                    OptionalIntPicker(title: "スヌーズ", value: $draft.snoozeCount, range: 0...10, unit: "回")
                    OptionalIntPicker(title: "二度寝", value: $draft.secondSleepMinutes, values: [0, 10, 20, 30, 45, 60, 90, 120], unit: "分")
                    OptionalIntPicker(title: "昼寝", value: $draft.napMinutes, values: [0, 10, 20, 30, 45, 60, 90, 120], unit: "分")
                    OptionalBoolPicker(title: "飲酒", value: $draft.consumedAlcohol, trueLabel: "あり", falseLabel: "なし")
                    OptionalBoolPicker(title: "カフェイン", value: $draft.consumedCaffeine, trueLabel: "摂取した", falseLabel: "摂取していない")
                    Toggle("スマートフォン終了時刻を記録", isOn: Binding(
                        get: { draft.smartphoneEndTime != nil },
                        set: { draft.smartphoneEndTime = $0 ? Date() : nil }
                    ))
                    if draft.smartphoneEndTime != nil {
                        DatePicker("終了時刻", selection: Binding(
                            get: { draft.smartphoneEndTime ?? Date() },
                            set: { draft.smartphoneEndTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                    OptionalRatingPicker(title: "ストレス", value: $draft.stress)
                    OptionalRatingPicker(title: "快適さ", value: $draft.comfort)
                    OptionalBoolPicker(title: "いびきの指摘", value: $draft.reportedSnoring, trueLabel: "指摘あり", falseLabel: "なし")
                    OptionalBoolPicker(title: "呼吸が止まったとの指摘", value: $draft.reportedBreathingPause, trueLabel: "指摘あり", falseLabel: "なし")
                }
                Text("任意項目は空欄のままで構いません。「未入力」と「なし／0回」は区別して保存されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                        LabeledContent("ベッド", value: record.bedTime.formatted(date: .omitted, time: .shortened))
                        LabeledContent("入眠", value: record.sleepStart.formatted(date: .omitted, time: .shortened))
                        LabeledContent("起床", value: record.wakeTime.formatted(date: .omitted, time: .shortened))
                        LabeledContent("睡眠時間", value: durationText(record.sleepDuration))
                        LabeledContent("スッキリ度", value: record.freshness.displayName)
                    }
                    Text("時刻の順序や睡眠時間を確認してください。極端な値は自動補正せず、前の画面で修正できます。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("保存する") { save(record) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(isSaving)
                    Button("入力に戻る") { phase = .form }
                        .frame(maxWidth: .infinity)
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
            switch try repository.save(record) {
            case .created(let saved):
                growthPointsEarned = SheepGrowthService.pointsPerRecord
                savedRecord = saved
                score = try scoringService.score(record: saved, settings: settings)
                comparison = try makeComparison(for: saved)
                phase = .result
                onSaved()
            case .updated(let saved):
                growthPointsEarned = 0
                savedRecord = saved
                score = try scoringService.score(record: saved, settings: settings)
                comparison = try makeComparison(for: saved)
                phase = .result
                onSaved()
            case .duplicate(let existing):
                duplicate = existing
            }
        } catch {
            errorMessage = error.localizedDescription
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
        Picker(title, selection: Binding(
            get: { value ?? -1 },
            set: { value = $0 < 0 ? nil : $0 }
        )) {
            Text("未入力").tag(-1)
            ForEach(values, id: \.self) { Text("\($0)\(unit)").tag($0) }
        }
    }
}

private struct OptionalBoolPicker: View {
    let title: String
    @Binding var value: Bool?
    let trueLabel: String
    let falseLabel: String
    var body: some View {
        Picker(title, selection: Binding(
            get: { value.map { $0 ? 1 : 0 } ?? -1 },
            set: { value = $0 < 0 ? nil : $0 == 1 }
        )) {
            Text("未入力").tag(-1)
            Text(falseLabel).tag(0)
            Text(trueLabel).tag(1)
        }
    }
}

private struct OptionalRatingPicker: View {
    let title: String
    @Binding var value: Rating?
    var body: some View {
        Picker(title, selection: Binding(
            get: { value?.rawValue ?? 0 },
            set: { value = Rating(rawValue: $0) }
        )) {
            Text("未入力").tag(0)
            ForEach(Rating.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) }
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
