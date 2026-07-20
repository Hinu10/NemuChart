import SwiftUI

struct SettingsView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    let onSaved: (UserSettings) -> Void
    let onDeleteAll: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var desiredMinutes: Int
    @State private var wakeTime: Date
    @State private var weekStart: WeekStart
    @State private var notificationsEnabled: Bool
    @State private var authorizationState: NotificationAuthorizationState
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var saveStatus = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var hasPendingChanges = false

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
        _desiredMinutes = State(initialValue: Int(settings.desiredSleepDuration / 60))
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("希望睡眠時間")
                        Picker("希望睡眠時間", selection: $desiredMinutes) {
                            ForEach(Array(stride(from: 3 * 60, through: 16 * 60, by: 15)), id: \.self) { minutes in
                                Text(durationText(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .accessibilityValue(durationText(desiredMinutes))
                    }
                    DatePicker("通常の起床時刻", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    Picker("週の開始曜日", selection: $weekStart) {
                        Text("月曜日").tag(WeekStart.monday)
                        Text("日曜日").tag(WeekStart.sunday)
                    }
                }
                Section("通知") {
                    Toggle("休む準備の通知", isOn: $notificationsEnabled)
                    LabeledContent("OSの許可状態", value: authorizationState.displayName)
                    if authorizationState == .denied {
                        Button("OSの設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    Text("目標ベッド時刻の30分前に、端末を置くための案内を1件予約します。通知の配信は保証されません。初期状態はOFFです。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("追加機能") {
                    NavigationLink("分析・アラーム・書き出し") {
                        FutureFeaturesView(dependencies: dependencies)
                    }
                }
                Section("データ管理") {
                    Button("すべてのデータを削除", role: .destructive) { showingDeleteConfirmation = true }
                    Text("睡眠記録、目標、設定をこの端末から削除します。取り消せません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("注意事項") {
                    Text("睡眠スコアは、睡眠時間40点、起床時刻25点、スッキリ度25点、睡眠の分断10点を基本とする参考値です。医療上の評価ではありません。")
                    Text("NemuChartは診断や治療を行いません。強い眠気などが続いて気になる場合は、医療機関などへの相談を検討してください。記録は端末内に保存し、外部へ送信しません。")
                    if !saveStatus.isEmpty {
                        Label(saveStatus, systemImage: saveStatus == "保存済み" ? "checkmark.circle" : "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(saveStatus == "保存済み" ? .green : .orange)
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar { Button("閉じる") { dismiss() } }
            .task { authorizationState = await dependencies.notificationService.authorizationState() }
            .onChange(of: desiredMinutes) { _, _ in scheduleSave() }
            .onChange(of: wakeTime) { _, _ in scheduleSave() }
            .onChange(of: weekStart) { _, _ in scheduleSave() }
            .onChange(of: notificationsEnabled) { _, enabled in
                Task {
                    await updateNotification(enabled)
                    scheduleSave()
                }
            }
            .onDisappear {
                saveTask?.cancel()
                saveIfNeeded()
            }
        }
        .confirmationDialog("すべてのデータを削除しますか？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("すべて削除", role: .destructive) { deleteAll() }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("この操作は取り消せません。") }
        .alert("操作を完了できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func scheduleSave() {
        hasPendingChanges = true
        saveStatus = "保存中…"
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            saveIfNeeded()
        }
    }

    private func saveIfNeeded() {
        guard hasPendingChanges else { return }
        do {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
            let updated = try UserSettings(
                id: settings.id,
                hasCompletedOnboarding: true,
                desiredSleepDuration: TimeInterval(desiredMinutes * 60),
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
            if updated.notificationPreference.isEnabledInApp {
                Task {
                    let goals = try? dependencies.sleepGoalRepository.goals()
                    if let goal = goals?.first {
                        try? await dependencies.notificationService.scheduleWindDown(before: goal.targetBedTime)
                    }
                }
            } else {
                dependencies.notificationService.cancelWindDown()
            }
            onSaved(updated)
            hasPendingChanges = false
            saveStatus = "保存済み"
        } catch {
            saveStatus = "保存できませんでした"
            errorMessage = error.localizedDescription
        }
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
            hasPendingChanges = false
            saveTask?.cancel()
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

    private func durationText(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60)時間" : "\(minutes / 60)時間\(minutes % 60)分"
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
