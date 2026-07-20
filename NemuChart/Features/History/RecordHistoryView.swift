import SwiftUI

struct RecordHistoryView: View {
    let repository: any SleepRecordRepository
    let scoringService: any ScoringServiceProtocol
    let settings: UserSettings
    var feedbackService: SheepFeedbackService = SheepFeedbackService()
    var goalRepository: (any SleepGoalRepository)?
    var preferences: AppPreferencesStore?
    var notificationService: (any LocalNotificationServiceProtocol)?
    var onChanged: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var records: [SleepRecord] = []
    @State private var selectedRecord: SleepRecord?
    @State private var errorMessage: String?
    @State private var pendingDeletion: SleepRecord?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("記録はまだありません", systemImage: "bed.double")
                } else {
                    List(records) { record in
                        Button {
                            selectedRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.sleepDay.key).font(.headline)
                                if record.isAllNighter {
                                    Text("徹夜 ・ 睡眠時間 0時間")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                } else {
                                    Text("睡眠 \(timeRangeText(record))")
                                        .font(.subheadline).bold()
                                    Text("\(durationText(record.sleepDuration)) ・ \(record.freshness.displayName)")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("削除", role: .destructive) { pendingDeletion = record }
                        }
                    }
                }
            }
            .navigationTitle("過去の記録")
            .toolbar { Button("閉じる") { dismiss() } }
            .task { load() }
        }
        .sheet(item: $selectedRecord) { record in
            SleepRecordFlow(
                repository: repository,
                scoringService: scoringService,
                settings: settings,
                feedbackService: feedbackService,
                goalRepository: goalRepository,
                preferences: preferences,
                notificationService: notificationService,
                initialRecord: record,
                onSaved: { load(); onChanged() }
            )
        }
        .confirmationDialog("この睡眠記録を削除しますか？", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("記録を削除", role: .destructive) { deletePendingRecord() }
            Button("キャンセル", role: .cancel) { pendingDeletion = nil }
        } message: { Text("関連するスコアと週間進捗も再計算されます。") }
        .alert("読み込めませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        do { records = try repository.records() }
        catch { errorMessage = error.localizedDescription }
    }

    private func deletePendingRecord() {
        guard let pendingDeletion else { return }
        do {
            try repository.delete(id: pendingDeletion.id)
            self.pendingDeletion = nil
            load()
            onChanged()
        } catch { errorMessage = error.localizedDescription }
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return "\(minutes / 60)時間\(minutes % 60)分"
    }

    private func timeRangeText(_ record: SleepRecord) -> String {
        let timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let crossesDay = !calendar.isDate(record.sleepStart, inSameDayAs: record.wakeTime)
        return "\(formatter.string(from: record.sleepStart))〜\(crossesDay ? "翌" : "")\(formatter.string(from: record.wakeTime))"
    }
}
