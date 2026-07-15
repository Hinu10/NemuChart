import SwiftUI

struct HomeView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    var onSettingsChanged: (UserSettings) -> Void = { _ in }
    var onResetAllData: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()
    @State private var showingRecord = false
    @State private var showingHistory = false
    @State private var showingWeekly = false
    @State private var showingWeeklyGoal = false
    @State private var showingSettings = false
    @State private var records: [SleepRecord] = []
    @State private var scores: [DailySleepScore] = []
    @State private var weeklyMetrics: WeeklyMetrics?
    @State private var preferenceData = AppPreferenceData()
    @State private var safetyGuidance: SafetyGuidance?
    @State private var loadError: String?

    private var period: HomeTimeOfDay { TimeOfDayPolicy().period(at: now) }
    private var vitality: Vitality { dependencies.vitalityService.vitality(scores: scores) }
    private var growth: SheepGrowthSummary {
        dependencies.growthService.summary(
            recordIDs: records.map(\.id),
            completedWeeklyGoalIDs: Array(preferenceData.rewardedWeeklyGoalIDs)
        )
    }
    private var landscape: LandscapeState { dependencies.landscapeService.state(timeOfDay: period, vitality: vitality) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(period.title).font(.largeTitle.bold())
                    Text(period.message).font(.title3).foregroundStyle(.secondary)
                    landscapeCard
                    if let safetyGuidance { safetyCard(safetyGuidance) }
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
                        .frame(minHeight: 44)
                        .accessibilityHint("朝以外でも睡眠入力画面を開きます")
                    Button {
                        showingWeekly = true
                    } label: {
                        Label("7日間の分析を見る", systemImage: "chart.bar.xaxis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        showingWeeklyGoal = true
                    } label: {
                        Label("週間目標を確認", systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("NemuChart")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("過去の記録", systemImage: "clock.arrow.circlepath") { showingHistory = true }
                    Button("設定", systemImage: "gearshape") { showingSettings = true }
                }
            }
        }
        .sheet(isPresented: $showingRecord) {
            SleepRecordFlow(
                repository: dependencies.sleepRecordRepository,
                scoringService: dependencies.scoringService,
                settings: settings,
                feedbackService: dependencies.feedbackService,
                goalRepository: dependencies.sleepGoalRepository,
                preferences: dependencies.preferences,
                notificationService: dependencies.notificationService,
                onSaved: loadDashboard
            )
        }
        .sheet(isPresented: $showingHistory) {
            RecordHistoryView(
                repository: dependencies.sleepRecordRepository,
                scoringService: dependencies.scoringService,
                settings: settings,
                feedbackService: dependencies.feedbackService,
                goalRepository: dependencies.sleepGoalRepository,
                preferences: dependencies.preferences,
                notificationService: dependencies.notificationService,
                onChanged: loadDashboard
            )
        }
        .sheet(isPresented: $showingWeekly) {
            WeeklyDashboardView(
                repository: dependencies.sleepRecordRepository,
                scoringService: dependencies.scoringService,
                analysisService: dependencies.weeklyAnalysisService,
                settings: settings
            )
        }
        .sheet(isPresented: $showingWeeklyGoal, onDismiss: loadDashboard) {
            WeeklyGoalView(
                repository: dependencies.sleepRecordRepository,
                sleepGoalRepository: dependencies.sleepGoalRepository,
                preferences: dependencies.preferences,
                progressService: dependencies.weeklyGoalProgressService,
                settings: settings
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                dependencies: dependencies,
                settings: settings,
                onSaved: onSettingsChanged,
                onDeleteAll: onResetAllData
            )
        }
        .task { loadDashboard() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date(); loadDashboard() }
        }
        .alert("データを読み込めませんでした", isPresented: Binding(
            get: { loadError != nil }, set: { if !$0 { loadError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(loadError ?? "") }
    }

    private var landscapeCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: period.symbol)
                Spacer()
                Image(systemName: landscape.mood.symbol)
            }
            .font(.title).accessibilityHidden(true)
            Text("🐑")
                .font(.system(size: 72))
                .scaleEffect(reduceMotion ? 1 : (vitality == .radiant ? 1.04 : 1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: vitality)
                .accessibilityLabel("羊は\(vitality.displayName)状態です")
            ViewThatFits(in: .horizontal) {
                HStack { sheepStateSummary; Spacer(); growthSummary }
                VStack(alignment: .leading, spacing: 8) { sheepStateSummary; growthSummary }
            }
            ProgressView(value: Double(weeklyMetrics?.recordedDayCount ?? 0), total: 7) {
                Text("今週の記録 \(weeklyMetrics?.recordedDayCount ?? 0) / 7日")
            }
        }
        .padding()
        .background(
            LinearGradient(colors: landscape.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .foregroundStyle(.primary)
    }

    private var sheepStateSummary: some View {
        VStack(alignment: .leading) {
            Text("元気度").font(.caption).foregroundStyle(.secondary)
            Text(vitality.displayName).bold()
        }
    }

    private var growthSummary: some View {
        VStack(alignment: .leading) {
            Text("成長").font(.caption).foregroundStyle(.secondary)
            Text("\(growth.stage.displayName)・\(growth.points.value) pt").bold()
        }
    }

    private func safetyCard(_ guidance: SafetyGuidance) -> some View {
        GroupBox(guidance.title) {
            VStack(alignment: .leading, spacing: 12) {
                Text(guidance.message)
                Button("この案内を閉じる") {
                    do {
                        preferenceData.safetyGuidanceDismissedAt = Date()
                        try dependencies.preferences.save(preferenceData)
                        safetyGuidance = nil
                    } catch { loadError = error.localizedDescription }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func loadDashboard() {
        do {
            records = try dependencies.sleepRecordRepository.records()
            scores = try records.map { try dependencies.scoringService.score(record: $0, settings: settings) }
            let endDay = try dependencies.dateTimeService.sleepDay(for: now, timeZoneIdentifier: TimeZone.current.identifier)
            weeklyMetrics = try dependencies.weeklyAnalysisService.metrics(
                records: records, endDay: endDay, settings: settings, scoringService: dependencies.scoringService
            )
            preferenceData = dependencies.preferences.load()
            try refreshWeeklyGoalIfNeeded()
            safetyGuidance = dependencies.safetyGuidanceService.guidance(
                records: records, dismissedAt: preferenceData.safetyGuidanceDismissedAt
            )
        } catch { loadError = error.localizedDescription }
    }

    private func refreshWeeklyGoalIfNeeded() throws {
        guard let existing = preferenceData.weeklyGoal else { return }
        let start = try dependencies.weeklyGoalProgressService.weekStart(
            containing: now, settings: settings
        )
        let latestGoal = try dependencies.sleepGoalRepository.goals().first
        let progress = try dependencies.weeklyGoalProgressService.progress(
            kind: existing.kind,
            targetCount: existing.targetCount,
            weekStart: start,
            records: records,
            settings: settings,
            latestGoal: latestGoal
        )
        let updated = try WeeklyGoal(
            id: existing.id,
            kind: existing.kind,
            weekStart: start,
            targetCount: existing.targetCount,
            completedCount: progress.completedCount
        )
        preferenceData.weeklyGoal = updated
        if updated.completedCount >= updated.targetCount {
            preferenceData.rewardedWeeklyGoalIDs.insert(updated.id)
        }
        try dependencies.preferences.save(preferenceData)
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

private extension Vitality {
    var displayName: String {
        switch self {
        case .resting: "眠そう（休息中）"
        case .calm: "穏やか"
        case .lively: "元気"
        case .radiant: "とても元気"
        }
    }
}

private extension GrowthStage {
    var displayName: String {
        switch self {
        case .lamb: "こひつじ"
        case .young: "わかひつじ"
        case .grown: "おとな"
        case .companion: "相棒"
        }
    }
}

private extension LandscapeMood {
    var symbol: String {
        switch self {
        case .clear: "sun.max.fill"
        case .gentle: "cloud.sun.fill"
        case .cloudy: "cloud.drizzle.fill"
        }
    }
}

private extension LandscapeState {
    var colors: [Color] {
        switch (timeOfDay, mood) {
        case (.morning, .clear): [.orange.opacity(0.35), .blue.opacity(0.2)]
        case (.daytime, .clear): [.cyan.opacity(0.3), .yellow.opacity(0.25)]
        case (.evening, .clear): [.orange.opacity(0.35), .purple.opacity(0.25)]
        case (.night, .clear): [.indigo.opacity(0.35), .blue.opacity(0.2)]
        case (_, .gentle): [.mint.opacity(0.22), .blue.opacity(0.16)]
        case (_, .cloudy): [.gray.opacity(0.22), .blue.opacity(0.12)]
        }
    }
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
