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
    @State private var alarmSound: AlarmSoundChoice
    @State private var alarmNotice: String?
    @State private var previewService: AlarmSoundPreviewService?
    @AppStorage("NemuChart.alarmEnabled") private var alarmEnabled = false

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
        _alarmSound = State(initialValue: preferences.load().alarmSound)
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
                if #available(iOS 26.0, *) {
                    Section("アラーム") {
                        Toggle("アラームを設定", isOn: $alarmEnabled)
                        Picker("音", selection: $alarmSound) {
                            ForEach(AlarmSoundChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Button {
                            preview()
                        } label: {
                            Label("音を試聴", systemImage: "speaker.wave.2")
                        }
                        .accessibilityHint("選んだアラーム音を一度だけ鳴らします")
                        if let alarmNotice {
                            Text(alarmNotice)
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        Text("アラームの『起きた！』で、押した時刻を記録画面に入力できます。スヌーズは\(NemuAlarmService.snoozeMinutes)分です。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("音量や集中モードなど端末の設定によって、聞こえ方や表示が変わることがあります。音の好みや起きやすさには個人差があり、特定の音の効果を保証するものではありません。")
                            .font(.footnote).foregroundStyle(.secondary)
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
                Text("変更内容は自動で保存されます。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("今夜の目標")
            .toolbar { Button("閉じる") { onSaved(); dismiss() } }
            .onChange(of: bedTime) { _, _ in save() }
            .onChange(of: sleepTime) { _, _ in save() }
            .onChange(of: wakeTime) { _, _ in save() }
            .onChange(of: actionGoal) { _, _ in save() }
            .onChange(of: alarmSound) { _, _ in save() }
            .onChange(of: alarmEnabled) { _, enabled in
                if enabled { scheduleAlarm() } else { NemuAlarmService.cancel(preferences: preferences) }
            }
            .onAppear {
                if alarmEnabled && NemuAlarmService.isAuthorizationDenied {
                    alarmEnabled = false
                    alarmNotice = NemuAlarmError.notAuthorized.errorDescription
                }
            }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let bed = localTime(bedTime)
        do {
            let existing = try repository.goals().first
            let active = existing.flatMap { Calendar.current.isDateInToday($0.createdAt) ? $0 : nil }
            let goal = try SleepGoal(
                id: active?.id ?? UUID(),
                targetBedTime: bed,
                targetSleepTime: localTime(sleepTime),
                targetWakeTime: localTime(wakeTime),
                timeZoneIdentifier: TimeZone.current.identifier,
                createdAt: active?.createdAt ?? Date()
            )
            try repository.save(goal)
            var preference = preferences.load()
            preference.actionGoal = actionGoal
            preference.alarmSound = alarmSound
            try preferences.save(preference)
            if settings.notificationPreference.isEnabledInApp {
                Task { try? await notificationService?.scheduleWindDown(before: bed) }
            }
            if alarmEnabled { scheduleAlarm() }
        } catch { errorMessage = error.localizedDescription }
    }

    private func scheduleAlarm() {
        guard #available(iOS 26.0, *) else { return }
        let time = localTime(wakeTime)
        let sound = alarmSound
        Task {
            do {
                let result = try await NemuAlarmService.schedule(wakeTime: time, sound: sound, preferences: preferences)
                alarmNotice = result.sound == sound ? nil : String(localized: "選んだ音を用意できなかったため、標準のアラーム音で設定しました。")
            } catch {
                alarmEnabled = false
                alarmNotice = error.localizedDescription
            }
        }
    }

    private func preview() {
        do {
            let service = previewService ?? AlarmSoundPreviewService()
            previewService = service
            try service.play(alarmSound)
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
