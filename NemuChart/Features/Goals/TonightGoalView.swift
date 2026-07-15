import SwiftUI

struct TonightGoalView: View {
    let settings: UserSettings
    let repository: any SleepGoalRepository
    let preferences: AppPreferencesStore
    let notificationService: (any LocalNotificationServiceProtocol)?
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wakeTime: Date
    @State private var sleepTime: Date
    @State private var bedTime: Date
    @State private var actionGoal: DailyActionGoal
    @State private var usedObservedLatency: Bool
    @State private var errorMessage: String?

    init(
        settings: UserSettings,
        records: [SleepRecord],
        repository: any SleepGoalRepository,
        preferences: AppPreferencesStore,
        planningService: GoalPlanningService = GoalPlanningService(),
        notificationService: (any LocalNotificationServiceProtocol)? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.repository = repository
        self.preferences = preferences
        self.notificationService = notificationService
        self.onSaved = onSaved
        let plan = planningService.plan(settings: settings, records: records)
        let wake = Self.date(plan.targetWakeTime)
        let sleep = Self.date(plan.targetSleepTime)
        let bed = Self.date(plan.targetBedTime)
        _wakeTime = State(initialValue: wake)
        _sleepTime = State(initialValue: sleep)
        _bedTime = State(initialValue: bed)
        _actionGoal = State(initialValue: preferences.load().actionGoal ?? .windDown)
        _usedObservedLatency = State(initialValue: plan.usedObservedLatency)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("今夜の目標") {
                    DatePicker("ベッドに入る", selection: $bedTime, displayedComponents: .hourAndMinute)
                    DatePicker("眠り始める目安", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    DatePicker("起きる", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    Picker("行動目標（1件）", selection: $actionGoal) {
                        ForEach(DailyActionGoal.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    Text(usedObservedLatency ? "直近3件以上の入眠までの時間を参考にしました。時刻は自由に編集できます。" : "記録がまだ少ないため、初回設定の値を使いました。時刻は自由に編集できます。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("予定どおりでなくても問題ありません。目標達成度は睡眠スコアとは別に扱います。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("保存したら、今日はもうアプリを開かなくても大丈夫です。")
                        .font(.headline)
                }
                Button("目標を保存") { save() }.frame(maxWidth: .infinity)
            }
            .navigationTitle("今夜の目標")
            .toolbar { Button("閉じる") { dismiss() } }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let bed = localTime(bedTime)
        do {
            let goal = try SleepGoal(
                targetBedTime: bed,
                targetSleepTime: localTime(sleepTime),
                targetWakeTime: localTime(wakeTime),
                timeZoneIdentifier: TimeZone.current.identifier
            )
            try repository.save(goal)
            var preference = preferences.load()
            preference.actionGoal = actionGoal
            try preferences.save(preference)
            if settings.notificationPreference.isEnabledInApp {
                Task { try? await notificationService?.scheduleWindDown(before: bed) }
            }
            onSaved()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func localTime(_ date: Date) -> LocalTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)!
    }

    private static func date(_ time: LocalTime) -> Date {
        Calendar.current.date(from: DateComponents(hour: time.hour, minute: time.minute)) ?? Date()
    }
}

extension DailyActionGoal {
    var displayName: String {
        switch self {
        case .windDown: "眠る前にゆっくり過ごす"
        case .avoidLateCaffeine: "遅い時間のカフェインを控える"
        case .putPhoneAway: "ベッド前に端末を置く"
        case .prepareMorning: "朝の準備を先に済ませる"
        }
    }
}
