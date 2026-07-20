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

    var body: some View {
        NavigationStack {
            Form {
                Section("週間目標を1件選ぶ") {
                    Picker("目標", selection: $kind) {
                        ForEach(WeeklyGoalKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Stepper("週に \(targetCount)回", value: $targetCount, in: 1...7)
                    Text(kind.conditionText).font(.footnote).foregroundStyle(.secondary)
                    Button("この目標に更新") { saveSelection() }
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
        }
        .alert("更新できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        let stored = preferences.load()
        if let storedGoal = stored.weeklyGoal {
            kind = storedGoal.kind
            targetCount = storedGoal.targetCount
        }
        refresh(existing: stored.weeklyGoal)
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
            let updated = try WeeklyGoal(
                id: existing?.id ?? UUID(), kind: kind, weekStart: start,
                targetCount: targetCount, completedCount: calculated.completedCount
            )
            goal = updated
            var data = preferences.load()
            let isSelected = shouldPersist || data.weeklyGoal != nil
            if isSelected { data.weeklyGoal = updated }
            if isSelected && data.weeklyGoalFirstConfiguredAt == nil {
                data.weeklyGoalFirstConfiguredAt = Date()
            }
            rewardGranted = data.rewardedWeeklyGoalIDs.contains(updated.id)
            if isSelected && updated.completedCount >= updated.targetCount && !rewardGranted {
                data.rewardedWeeklyGoalIDs.insert(updated.id)
                rewardGranted = true
            }
            try preferences.save(data)
        } catch { errorMessage = error.localizedDescription }
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
        }
    }
    var conditionText: String {
        switch self {
        case .recordSleep: "その週に睡眠記録がある日を数えます。"
        case .meetWakeTime: "通常の起床時刻から前後30分以内の日を数えます。"
        case .meetSleepDuration: "希望睡眠時間から前後30分以内の日を数えます。"
        case .endSmartphone: "スマートフォン終了時刻がベッド時刻以前の日を数えます。"
        case .meetBedtime: "最新の目標ベッド時刻から前後30分以内の日を数えます。"
        }
    }
}
