import SwiftUI

struct SettingsView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    let onSaved: (UserSettings) -> Void
    let onDeleteAll: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var desiredHours: Int
    @State private var wakeTime: Date
    @State private var weekStart: WeekStart
    @State private var notificationsEnabled: Bool
    @State private var authorizationState: NotificationAuthorizationState
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    init(
        dependencies: AppDependencies,
        settings: UserSettings,
        onSaved: @escaping (UserSettings) -> Void,
        onDeleteAll: @escaping () -> Void
    ) {
        self.dependencies = dependencies
        self.settings = settings
        self.onSaved = onSaved
        self.onDeleteAll = onDeleteAll
        _desiredHours = State(initialValue: Int(settings.desiredSleepDuration / 3600))
        _wakeTime = State(initialValue: Calendar.current.date(from: DateComponents(
            hour: settings.standardWakeTime.hour, minute: settings.standardWakeTime.minute
        )) ?? Date())
        _weekStart = State(initialValue: settings.weekStart)
        _notificationsEnabled = State(initialValue: settings.notificationPreference.isEnabledInApp)
        _authorizationState = State(initialValue: settings.notificationPreference.authorizationState)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("睡眠目標") {
                    Stepper("希望睡眠時間：\(desiredHours)時間", value: $desiredHours, in: 3...16)
                    DatePicker("通常の起床時刻", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    Picker("週の開始曜日", selection: $weekStart) {
                        Text("月曜日").tag(WeekStart.monday)
                        Text("日曜日").tag(WeekStart.sunday)
                    }
                }
                Section("通知") {
                    Toggle("休む準備の通知", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in Task { await updateNotification(enabled) } }
                    LabeledContent("OSの許可状態", value: authorizationState.displayName)
                    if authorizationState == .denied {
                        Button("OSの設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    Text("目標ベッド時刻の30分前に、端末を置くための案内を1件予約します。通知の配信は保証されません。初期状態はOFFです。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("説明と安全") {
                    DisclosureGroup("睡眠スコアの考え方") {
                        Text("睡眠時間40点、起床時刻25点、スッキリ度25点、睡眠の分断10点を基本とする参考値です。医療上の評価ではありません。")
                    }
                    DisclosureGroup("安全とプライバシー") {
                        Text("NemuChartは診断や治療を行いません。強い眠気などが続いて気になる場合は、医療機関などへの相談を検討してください。記録は端末内に保存し、外部へ送信しません。")
                    }
                }
                Section {
                    Button("設定を保存") { save() }.frame(maxWidth: .infinity)
                }
                Section("データ管理") {
                    Button("すべてのデータを削除", role: .destructive) { showingDeleteConfirmation = true }
                    Text("睡眠記録、目標、設定をこの端末から削除します。取り消せません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .toolbar { Button("閉じる") { dismiss() } }
            .task { authorizationState = await dependencies.notificationService.authorizationState() }
        }
        .confirmationDialog("すべてのデータを削除しますか？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("すべて削除", role: .destructive) { deleteAll() }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("この操作は取り消せません。") }
        .alert("操作を完了できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        do {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
            let updated = try UserSettings(
                id: settings.id,
                hasCompletedOnboarding: true,
                desiredSleepDuration: TimeInterval(desiredHours * 3600),
                standardWakeTime: LocalTime(hour: parts.hour ?? 7, minute: parts.minute ?? 0)!,
                averageSleepLatencyMinutes: settings.averageSleepLatencyMinutes,
                weekStart: weekStart,
                notificationPreference: NotificationPreference(
                    isEnabledInApp: notificationsEnabled,
                    authorizationState: authorizationState
                ),
                updatedAt: Date()
            )
            try dependencies.userSettingsRepository.save(updated)
            Task {
                if updated.notificationPreference.isEnabledInApp {
                    let goals = try? dependencies.sleepGoalRepository.goals()
                    if let goal = goals?.first {
                        try? await dependencies.notificationService.scheduleWindDown(before: goal.targetBedTime)
                    }
                } else {
                    dependencies.notificationService.cancelWindDown()
                }
            }
            onSaved(updated)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func updateNotification(_ enabled: Bool) async {
        do {
            if enabled {
                if authorizationState == .notDetermined {
                    authorizationState = try await dependencies.notificationService.requestAuthorization()
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteAll() {
        do {
            try DataDeletionService(
                sleepRecordRepository: dependencies.sleepRecordRepository,
                userSettingsRepository: dependencies.userSettingsRepository,
                sleepGoalRepository: dependencies.sleepGoalRepository,
                preferences: dependencies.preferences
            ).deleteAll()
            dependencies.notificationService.cancelWindDown()
            onDeleteAll()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private extension NotificationAuthorizationState {
    var displayName: String {
        switch self {
        case .notDetermined: "未選択"
        case .denied: "許可されていません"
        case .authorized: "許可済み"
        case .provisional: "仮許可"
        }
    }
}
