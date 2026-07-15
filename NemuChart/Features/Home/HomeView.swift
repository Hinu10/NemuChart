import SwiftUI

struct HomeView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var showingRecord = false
    @State private var showingHistory = false

    private var period: HomeTimeOfDay { TimeOfDayPolicy().period(at: now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: period.symbol)
                        .font(.system(size: 56))
                        .foregroundStyle(.indigo)
                        .accessibilityHidden(true)
                    Text(period.title).font(.largeTitle.bold())
                    Text(period.message).font(.title3).foregroundStyle(.secondary)
                    if period == .morning {
                        Button("昨夜の睡眠を記録する") { showingRecord = true }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    } else if period == .daytime || period == .evening {
                        GroupBox("今日の目安") {
                            Text("希望睡眠時間は \(Int(settings.desiredSleepDuration / 3600))時間です。今夜の目標は後から設定できます。")
                        }
                    } else {
                        Text("記録は明日の朝に。いまは端末を置いて、ゆっくり休みましょう。")
                            .padding()
                            .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button("時間帯にかかわらず記録する") { showingRecord = true }
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("NemuChart")
            .toolbar {
                Button("過去の記録", systemImage: "clock.arrow.circlepath") { showingHistory = true }
            }
        }
        .sheet(isPresented: $showingRecord) {
            SleepRecordFlow(
                repository: dependencies.sleepRecordRepository,
                scoringService: dependencies.scoringService,
                settings: settings
            )
        }
        .sheet(isPresented: $showingHistory) {
            RecordHistoryView(
                repository: dependencies.sleepRecordRepository,
                scoringService: dependencies.scoringService,
                settings: settings
            )
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
    }
}

#Preview {
    let dependencies = try! AppDependencies(modelContainer: ModelContainerFactory.make(inMemory: true))
    return HomeView(
        dependencies: dependencies,
        settings: try! UserSettings(
            hasCompletedOnboarding: true,
            desiredSleepDuration: 8 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!
        )
    )
}

private extension HomeTimeOfDay {
    var title: String {
        switch self {
        case .morning: "おはようございます"
        case .daytime: "今日のリズムを確認"
        case .evening: "そろそろ休む準備を"
        case .night: "おやすみなさい"
        }
    }
    var message: String {
        switch self {
        case .morning: "前夜の睡眠を、覚えている範囲で記録しましょう。"
        case .daytime: "今夜の目標を無理のない範囲で意識してみましょう。"
        case .evening: "眠る前の時間を穏やかに過ごしましょう。"
        case .night: "今は記録よりも休息を優先しましょう。"
        }
    }
    var symbol: String {
        switch self {
        case .morning: "sunrise.fill"
        case .daytime: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}
