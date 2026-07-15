import SwiftUI

struct RecordHistoryView: View {
    let repository: any SleepRecordRepository
    let scoringService: any ScoringServiceProtocol
    let settings: UserSettings
    var feedbackService: SheepFeedbackService = SheepFeedbackService()
    var goalRepository: (any SleepGoalRepository)?
    @Environment(\.dismiss) private var dismiss
    @State private var records: [SleepRecord] = []
    @State private var selectedRecord: SleepRecord?
    @State private var errorMessage: String?

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
                                Text("\(durationText(record.sleepDuration)) ・ \(record.freshness.displayName)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
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
                initialRecord: record,
                onSaved: load
            )
        }
        .alert("読み込めませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        do { records = try repository.records() }
        catch { errorMessage = error.localizedDescription }
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
}
