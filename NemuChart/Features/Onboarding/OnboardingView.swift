import SwiftUI

struct OnboardingView: View {
    let repository: any UserSettingsRepository
    let onComplete: (UserSettings) -> Void

    @State private var page = 0
    @State private var desiredHours = 8
    @State private var wakeTime = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
    @State private var weekStart = WeekStart.monday
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    explanation.tag(0)
                    settingsForm.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(page == 0 ? "設定へ進む" : "この内容で始める") {
                    if page == 0 { withAnimation { page = 1 } } else { save() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSaving)
                .accessibilityIdentifier("onboardingPrimaryButton")
            }
            .padding()
            .navigationTitle("はじめまして")
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var explanation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                Text("睡眠をやさしく振り返る")
                    .font(.largeTitle.bold())
                Text("毎朝の入力から、あなた自身の目標と比べた参考スコアを表示します。")
                GroupBox("大切なお知らせ") {
                    Text("NemuChartは医療機器ではなく、診断や治療を行いません。気になる症状が続く場合は、医療機関への相談を検討してください。")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
        }
    }

    private var settingsForm: some View {
        Form {
            Section("必須設定（3項目）") {
                Stepper("希望睡眠時間：\(desiredHours)時間", value: $desiredHours, in: 3...16)
                DatePicker("通常の起床時刻", selection: $wakeTime, displayedComponents: .hourAndMinute)
                Picker("週の開始曜日", selection: $weekStart) {
                    Text("月曜日").tag(WeekStart.monday)
                    Text("日曜日").tag(WeekStart.sunday)
                }
            }
            Section {
                Text("通知は、あとから設定画面で選べます。ここでは通知許可を求めません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        isSaving = true
        defer { isSaving = false }
        do {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
            guard let localTime = LocalTime(hour: parts.hour ?? 7, minute: parts.minute ?? 0) else {
                throw DateTimeError.invalidDateComponents
            }
            let settings = try UserSettings(
                hasCompletedOnboarding: true,
                desiredSleepDuration: TimeInterval(desiredHours * 60 * 60),
                standardWakeTime: localTime,
                weekStart: weekStart,
                updatedAt: Date()
            )
            try repository.save(settings)
            onComplete(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
