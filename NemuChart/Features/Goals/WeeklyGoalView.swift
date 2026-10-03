import SwiftUI

struct WeeklyGoalView: View {
    let repository: any SleepRecordRepository
    let sleepGoalRepository: any SleepGoalRepository
    let preferences: AppPreferencesStore
    let progressService: WeeklyGoalProgressService
    let settings: UserSettings
    let proposedWeekStart: SleepDay?
    @Environment(\.dismiss) private var dismiss
    @State private var kind = WeeklyGoalKind.recordSleep
    @State private var targetCount = 3
    @State private var goal: WeeklyGoal?
    @State private var rewardGranted = false
    @State private var errorMessage: String?
    @State private var showingMore = false
    @State private var customText = ""
    @State private var customCompleted = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("週間目標を1件選ぶ") {
                    Picker("目標", selection: $kind) {
                        ForEach(recommended, id: \.self) { Text($0.displayName).tag($0) }
                        if showingMore || !recommended.contains(kind) {
                            ForEach(additional, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                    if !showingMore {
                        Button("ほかの目標を見る") { showingMore = true }
                    }
                    Stepper("週に \(targetCount)回", value: $targetCount, in: 1...7)
                    Text(kind.conditionText).font(.footnote).foregroundStyle(.secondary)
                    if kind == .custom {
                        TextField("自分の目標", text: $customText)
                        Toggle("達成した", isOn: $customCompleted)
                    }
                }
                if let goal {
                    Section("今週の進捗") {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(goal.completedCount) / \(goal.targetCount)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            Text("回")
                        }
                        ProgressView(value: goal.progress)
                            .accessibilityLabel("週間目標の進捗")
                            .accessibilityValue("\(goal.completedCount)回、目標\(goal.targetCount)回")
                        Text("残り \(progressService.remainingDays(weekStart: goal.weekStart))日。記録のない日は失敗とは扱いません。")
                        if goal.completedCount >= goal.targetCount {
                            Label(rewardGranted ? "達成報酬15ポイントを受け取りました" : "達成済み", systemImage: "star.fill")
                        } else {
                            Text("できる日に少しずつ。連続でなくても大丈夫です。")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("週間目標")
            .toolbar { Button("閉じる") { dismiss() } }
            .task { load() }
            .onChange(of: kind) { _, _ in if !isLoading { saveSelection() } }
            .onChange(of: targetCount) { _, _ in if !isLoading { saveSelection() } }
            .onChange(of: customText) { _, _ in if !isLoading { saveSelection() } }
            .onChange(of: customCompleted) { _, _ in if !isLoading { saveSelection() } }
        }
        .alert("更新できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        isLoading = true
        let stored = preferences.load()
        customText = stored.customWeeklyGoalText
        customCompleted = stored.customWeeklyGoalCompleted
        if let storedGoal = stored.weeklyGoal {
            kind = storedGoal.kind
            targetCount = storedGoal.targetCount
        }
        refresh(existing: stored.weeklyGoal)
        isLoading = false
    }

    private func saveSelection() {
        refresh(existing: goal?.kind == kind && goal?.targetCount == targetCount ? goal : nil, shouldPersist: true)
    }

    private func refresh(existing: WeeklyGoal?, shouldPersist: Bool = false) {
        do {
            let records = try repository.records()
            let start = try proposedWeekStart ?? progressService.mondayStart(containing: Date())
            let latestGoal = try sleepGoalRepository.goals().first
            let calculated = try progressService.progress(
                kind: kind, targetCount: targetCount, weekStart: start,
                records: records, settings: settings, latestGoal: latestGoal
            )
            let completed = kind == .custom ? (customCompleted ? targetCount : 0) : calculated.completedCount
            let updated = try WeeklyGoal(
                id: existing?.id ?? UUID(), kind: kind, weekStart: start,
                targetCount: targetCount, completedCount: completed
            )
            goal = updated
            var data = preferences.load()
            let isSelected = shouldPersist || data.weeklyGoal != nil
            if shouldPersist, let prior = data.weeklyGoal, prior.id != updated.id {
                data.rewardedWeeklyGoalIDs.remove(prior.id)
                data.weeklyGoalHistory.removeAll { $0.id == prior.id }
            }
            if isSelected { data.weeklyGoal = updated }
            if isSelected {
                data.weeklyGoalHistory.removeAll { $0.id == updated.id }
                data.weeklyGoalHistory.append(updated)
            }
            data.customWeeklyGoalText = customText
            data.customWeeklyGoalCompleted = customCompleted
            if isSelected && data.weeklyGoalFirstConfiguredAt == nil {
                data.weeklyGoalFirstConfiguredAt = Date()
            }
            rewardGranted = data.rewardedWeeklyGoalIDs.contains(updated.id)
            if isSelected && updated.completedCount >= updated.targetCount && !rewardGranted {
                data.rewardedWeeklyGoalIDs.insert(updated.id)
                rewardGranted = true
            } else if updated.completedCount < updated.targetCount {
                data.rewardedWeeklyGoalIDs.remove(updated.id)
                rewardGranted = false
            }
            try preferences.save(data)
        } catch { errorMessage = error.localizedDescription }
    }

    private var recommended: [WeeklyGoalKind] {
        [.recordSleep, .meetWakeTime, .meetSleepDuration, .freshness70, .meetTonightGoal]
    }
    private var additional: [WeeklyGoalKind] {
        [.sevenHours, .avoidShortSleep, .freshness60, .freshness80, .avoidCaffeine,
         .avoidAlcohol, .limitNap, .endSmartphone, .noteStress, .meetBedtime, .custom]
    }
}

extension WeeklyGoalKind {
    var displayName: String {
        switch self {
        case .recordSleep: "朝に睡眠を記録する"
        case .meetWakeTime: "予定に近い時刻に起きる"
        case .meetSleepDuration: "希望に近い睡眠時間を取る"
        case .endSmartphone: "ベッド前に端末を置く"
        case .meetBedtime: "目標に近い時刻にベッドへ入る"
        case .meetTonightGoal: "今夜の目標を達成する"
        case .freshness70: "スッキリ度70以上を目指す"
        case .sevenHours: "7時間以上眠る"
        case .avoidShortSleep: "6時間未満の睡眠を避ける"
        case .freshness60: "スッキリ度60以上"
        case .freshness80: "スッキリ度80以上"
        case .avoidCaffeine: "カフェインを控える"
        case .avoidAlcohol: "飲酒を控える"
        case .limitNap: "昼寝を長くしすぎない"
        case .noteStress: "ストレスを意識して記録する"
        case .custom: "自分で目標を作る"
        }
    }
    var conditionText: String {
        switch self {
        case .recordSleep: "その週に睡眠記録がある日を数えます。"
        case .meetWakeTime: "理想の起床時間から前後15分以内の日を数えます。"
        case .meetSleepDuration: "希望睡眠時間から前後30分以内の日を数えます。"
        case .endSmartphone: "スマートフォン終了時刻がベッド時刻以前の日を数えます。"
        case .meetBedtime: "最新の目標ベッド時刻から前後30分以内の日を数えます。"
        case .meetTonightGoal: "今夜の目標に近い就寝・起床時刻の日を数えます。"
        case .freshness70, .freshness60, .freshness80: "記録したスッキリ度で振り返ります。"
        case .sevenHours, .avoidShortSleep: "記録した睡眠時間で振り返ります。"
        case .avoidCaffeine, .avoidAlcohol, .limitNap, .noteStress: "記録した生活要因で振り返ります。"
        case .custom: "自分で達成をチェックできます。"
        }
    }
}
