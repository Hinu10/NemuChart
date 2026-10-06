import SwiftUI

struct TonightGoalView: View {
    let settings: UserSettings
    let repository: any SleepGoalRepository
    let preferences: AppPreferencesStore
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wakeTime: Date
    @State private var sleepTime: Date
    @State private var actionGoal: DailyActionGoal
    @State private var errorMessage: String?
    @State private var alarmSound: AlarmSoundChoice
    @State private var alarmNotice: String?
    @State private var previewService: AlarmSoundPreviewService?
    @State private var scheduledAlarm: (date: Date, sound: AlarmSoundChoice)?
    @State private var isScheduling = false
    @State private var wentToBedAt: Date?
    @AppStorage("NemuChart.alarmEnabled") private var alarmEnabled = false
    @AppStorage("NemuChart.morningNotificationEnabled") private var morningNotificationEnabled = false

    init(
        settings: UserSettings,
        records: [SleepRecord],
        repository: any SleepGoalRepository,
        preferences: AppPreferencesStore,
        planningService: GoalPlanningService = GoalPlanningService(),
        onSaved: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.repository = repository
        self.preferences = preferences
        self.onSaved = onSaved
        let plan = planningService.plan(settings: settings, records: records)
        // 今日すでに保存した目標があれば、開き直しても提案値に戻さずその時刻を出す。
        let saved = (try? repository.goals().first).flatMap { Calendar.current.isDateInToday($0.createdAt) ? $0 : nil }
        _wakeTime = State(initialValue: Self.date(saved?.targetWakeTime ?? plan.targetWakeTime))
        // 眠り始める目安時間は、画面を開いた時刻を初期値にする。
        _sleepTime = State(initialValue: Date())
        _actionGoal = State(initialValue: preferences.load().actionGoal ?? .windDown)
        _alarmSound = State(initialValue: preferences.load().alarmSound)
        _scheduledAlarm = State(initialValue: NemuAlarmService.upcoming(in: preferences.load()).map { ($0.date, $0.sound) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("今夜の目標") {
                    DatePicker("眠り始める目安時間", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    DatePicker("起きる", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    Picker("行動目標（1件）", selection: $actionGoal) {
                        ForEach(DailyActionGoal.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                if #available(iOS 26.0, *) {
                    Section("アラーム") {
                        alarmControls
                        Picker("音", selection: $alarmSound) {
                            ForEach(AlarmSoundChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Button {
                            preview()
                        } label: {
                            Label("音を試聴", systemImage: "speaker.wave.2")
                        }
                        .accessibilityHint("選んだアラーム音を一度だけ鳴らします")
                        if alarmSound.speechText != nil {
                            Text("声の音は、この iPhone の読み上げ音声で作ります。初回の予約に少し時間がかかることがあります。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let alarmNotice {
                            Text(alarmNotice)
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        Text("アラームは「セット」を押したときだけ予約されます。時刻や音を変えても、セットし直すまで前の内容で鳴ります。『起きた！』で押した時刻を記録画面に入力できます。スヌーズは\(NemuAlarmService.snoozeMinutes)分です。")
                            .font(.footnote).foregroundStyle(.secondary)
                        // セットしていないときに勝手に音が鳴らないことを伝える。通知をオンにしていれば通知音だけは鳴る。
                        Text(soundNote)
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("音量や集中モードなど端末の設定によって、聞こえ方や表示が変わることがあります。音の好みや起きやすさには個人差があり、特定の音の効果を保証するものではありません。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("眠り始める目安時間は、この画面を開いた時刻を最初に表示しています。時刻は自由に編集できます。")
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
            .onChange(of: sleepTime) { _, _ in save() }
            .onChange(of: wakeTime) { _, _ in save() }
            .onChange(of: actionGoal) { _, _ in save() }
            .onChange(of: alarmSound) { _, _ in save() }
            .onAppear {
                if scheduledAlarm != nil && NemuAlarmService.isAuthorizationDenied {
                    cancelAlarm()
                    alarmNotice = NemuAlarmError.notAuthorized.errorDescription
                }
            }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        // ベッドに入る時刻は入力欄をなくしたため、眠り始める目安時間と同じにする。
        let bed = localTime(sleepTime)
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
            // 休む準備の通知は、開いた時刻で変わる目安時間ではなく設定から決める（設定画面と起動時に予約する）。
        } catch { errorMessage = error.localizedDescription }
    }

    @ViewBuilder
    private var alarmControls: some View {
        let time = wakeTime.formatted(date: .omitted, time: .shortened)
        if let scheduledAlarm {
            LabeledContent("セット中") {
                Text("\(Self.dayLabel(scheduledAlarm.date)) \(scheduledAlarm.date.formatted(date: .omitted, time: .shortened))")
            }
            if localTime(scheduledAlarm.date) != localTime(wakeTime) || scheduledAlarm.sound != alarmSound {
                Button {
                    scheduleAlarm()
                } label: {
                    Label("\(time)・\(alarmSound.displayName)でセットし直す", systemImage: "arrow.clockwise")
                }
                .disabled(isScheduling)
            }
            Button("アラームを取り消す", role: .destructive) { cancelAlarm() }
                .disabled(isScheduling)
        } else {
            Button {
                scheduleAlarm()
            } label: {
                Label("\(time)にアラームをセット", systemImage: "alarm")
            }
            .disabled(isScheduling)
            Text("まだセットしていません。このボタンを押すまでアラームは鳴りません。")
                .font(.footnote).foregroundStyle(.orange)
        }
        Button {
            goToBedNow()
        } label: {
            Label("今から寝る", systemImage: "bed.double.fill")
        }
        .disabled(isScheduling)
        if let wentToBedAt {
            Text("\(wentToBedAt.formatted(date: .omitted, time: .shortened))に寝たことを記録しました。アラームの『起きた！』で、寝た時刻と起きた時刻が記録画面に入ります。")
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            Text("「今から寝る」を押すと、今の時刻を寝た時刻として残し、アラームがまだならこの時刻でセットします。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        if isScheduling {
            ProgressView("セットしています…")
        }
    }

    private func scheduleAlarm() {
        guard #available(iOS 26.0, *) else { return }
        let time = localTime(wakeTime)
        let sound = alarmSound
        isScheduling = true
        Task {
            defer { isScheduling = false }
            do {
                let result = try await NemuAlarmService.schedule(wakeTime: time, sound: sound, preferences: preferences)
                scheduledAlarm = (result.scheduledAt, result.sound)
                alarmEnabled = true
                alarmNotice = result.sound == sound ? nil : String(localized: "選んだ音を用意できなかったため、標準のアラーム音で設定しました。")
            } catch {
                alarmNotice = error.localizedDescription
            }
        }
    }

    private func goToBedNow() {
        let now = Date()
        NemuAlarmService.markWentToBed(at: now)
        wentToBedAt = now
        let needsScheduling = scheduledAlarm.map { localTime($0.date) != localTime(wakeTime) || $0.sound != alarmSound } ?? true
        if needsScheduling { scheduleAlarm() }
    }

    private func cancelAlarm() {
        NemuAlarmService.cancel(preferences: preferences)
        scheduledAlarm = nil
        alarmEnabled = false
    }

    private var soundNote: String {
        let windDown = settings.notificationPreference.isEnabledInApp
        switch (windDown, morningNotificationEnabled) {
        case (true, true): return String(localized: "セットしない限りアラーム音は鳴りません。通知をオンにしているため、寝る前と朝の通知音は鳴ります。")
        case (true, false): return String(localized: "セットしない限りアラーム音は鳴りません。休む準備の通知をオンにしているため、寝る前の通知音は鳴ります。")
        case (false, true): return String(localized: "セットしない限りアラーム音は鳴りません。朝の記録通知をオンにしているため、朝の通知音は鳴ります。")
        case (false, false): return String(localized: "セットしない限り、アプリから音が鳴ることはありません。")
        }
    }

    private static func dayLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? String(localized: "今日") : String(localized: "明日")
    }

    private func preview() {
        do {
            let service = previewService ?? AlarmSoundPreviewService()
            previewService = service
            try service.play(alarmSound)
            alarmNotice = nil
        } catch {
            alarmNotice = String(localized: "音を再生できませんでした。ほかのアプリが音を使っていないか確認して、もう一度お試しください。")
        }
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
