import SwiftUI

struct TonightGoalView: View {
    let settings: UserSettings
    let repository: any SleepGoalRepository
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wakeTime: Date
    @State private var sleepTime: Date
    @State private var bedTime: Date
    @State private var errorMessage: String?

    init(settings: UserSettings, repository: any SleepGoalRepository, onSaved: @escaping () -> Void = {}) {
        self.settings = settings
        self.repository = repository
        self.onSaved = onSaved
        let calendar = Calendar.current
        let wake = calendar.date(from: DateComponents(hour: settings.standardWakeTime.hour, minute: settings.standardWakeTime.minute)) ?? Date()
        let sleep = calendar.date(byAdding: .second, value: -Int(settings.desiredSleepDuration), to: wake) ?? wake
        let bed = calendar.date(byAdding: .minute, value: -(settings.averageSleepLatencyMinutes ?? 20), to: sleep) ?? sleep
        _wakeTime = State(initialValue: wake)
        _sleepTime = State(initialValue: sleep)
        _bedTime = State(initialValue: bed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("今夜の目標") {
                    DatePicker("ベッドに入る", selection: $bedTime, displayedComponents: .hourAndMinute)
                    DatePicker("眠り始める目安", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    DatePicker("起きる", selection: $wakeTime, displayedComponents: .hourAndMinute)
                }
                Section {
                    Text("予定どおりでなくても問題ありません。目標達成度は睡眠スコアとは別に扱います。")
                        .font(.footnote).foregroundStyle(.secondary)
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
        do {
            let goal = try SleepGoal(
                targetBedTime: localTime(bedTime),
                targetSleepTime: localTime(sleepTime),
                targetWakeTime: localTime(wakeTime),
                timeZoneIdentifier: TimeZone.current.identifier
            )
            try repository.save(goal)
            onSaved()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func localTime(_ date: Date) -> LocalTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)!
    }
}
