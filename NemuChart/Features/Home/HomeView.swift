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
    @State private var proposedWeeklyGoalStart: SleepDay?
    @State private var weeklyGoalPromptDismissedForSession = false
    @State private var showingSettings = false
    @State private var records: [SleepRecord] = []
    @State private var scores: [DailySleepScore] = []
    @State private var weeklyMetrics: WeeklyMetrics?
    @State private var preferenceData = AppPreferenceData()
    @State private var safetyGuidance: SafetyGuidance?
    @State private var loadError: String?
    @State private var sheepAnimating = false

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
                    Image("NemuChartLogoCropped")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 86)
                        .accessibilityLabel("NemuChart")
                    greetingHeader
                    landscapeCard
                    if let safetyGuidance { safetyCard(safetyGuidance) }
                    if period == .morning {
                        Button(hasRecordForCurrentSleepDay ? "睡眠を追加で記録する" : "昨夜の睡眠を記録する") {
                            showingRecord = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else if period == .daytime || period == .evening {
                        GroupBox("今日の目安") {
                            Text(sleepDurationGuidance)
                        }
                    } else {
                        Text("記録は明日の朝に。いまは端末を置いて、ゆっくり休みましょう。")
                            .padding()
                            .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button {
                        showingWeekly = true
                    } label: {
                        Label("7日間の分析を見る", systemImage: "chart.bar.xaxis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    if let weeklyGoal = preferenceData.weeklyGoal {
                        weeklyGoalCard(weeklyGoal)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("")
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
        .sheet(isPresented: $showingWeeklyGoal, onDismiss: {
            weeklyGoalPromptDismissedForSession = true
            loadDashboard()
        }) {
            WeeklyGoalView(
                repository: dependencies.sleepRecordRepository,
                sleepGoalRepository: dependencies.sleepGoalRepository,
                preferences: dependencies.preferences,
                progressService: dependencies.weeklyGoalProgressService,
                settings: settings,
                proposedWeekStart: proposedWeeklyGoalStart
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
            if phase == .active {
                weeklyGoalPromptDismissedForSession = false
                now = Date()
                loadDashboard()
            }
        }
        .alert("データを読み込めませんでした", isPresented: Binding(
            get: { loadError != nil }, set: { if !$0 { loadError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(loadError ?? "") }
    }

    private var landscapeCard: some View {
        ZStack {
            Image("sheep-landscape")
                .resizable()
                .scaledToFill()
                .overlay(landscapeTint)
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: period.symbol)
                    Spacer()
                    Image(systemName: landscape.mood.symbol)
                }
                .font(.title)
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .accessibilityHidden(true)
                animatedSheep
                ViewThatFits(in: .horizontal) {
                    HStack { sheepStateSummary; Spacer(); growthSummary }
                    VStack(alignment: .leading, spacing: 8) { sheepStateSummary; growthSummary }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                ProgressView(value: Double(weeklyMetrics?.recordedDayCount ?? 0), total: 7) {
                    Text("今週の記録 \(weeklyMetrics?.recordedDayCount ?? 0) / 7日")
                }
                .tint(.white)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .frame(minHeight: 410)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .onAppear { sheepAnimating = true }
    }

    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: period.symbol)
                .font(.title)
                .foregroundStyle(period.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(period.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(period.titleGradient)
                    .shadow(color: period.accentColor.opacity(0.22), radius: 5, y: 2)
                Text(period.message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
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

    private var hasRecordForCurrentSleepDay: Bool {
        guard let day = try? dependencies.dateTimeService.sleepDay(
            for: now,
            timeZoneIdentifier: TimeZone.current.identifier
        ) else { return false }
        return records.contains { $0.sleepDay.key == day.key }
    }

    private var sheepAssetName: String {
        switch vitality {
        case .resting: "sheep-resting"
        case .calm: "sheep-calm"
        case .lively: "sheep-lively"
        case .radiant: "sheep-radiant"
        }
    }

    private var sheepScale: CGFloat { vitality == .radiant ? 1.05 : 1.01 }
    private var sheepRotation: Double { vitality == .resting ? 4.0 : vitality == .radiant ? 1.5 : 0.5 }
    private var sheepOffset: CGFloat { vitality == .resting ? 7 : vitality == .radiant ? -10 : vitality == .lively ? -4 : 1 }
    private var sheepAnimationDuration: Double { vitality == .radiant ? 0.7 : vitality == .resting ? 1.6 : 2.2 }

    private var sleepDurationGuidance: String {
        if settings.sleepDurationPreference == .inferred {
            return "快眠の基準はまだ仮設定です。いまは \(durationText(settings.desiredSleepDuration))を目安にして、記録が増えたら分析で見直せます。"
        }
        return "快眠の基準は \(durationText(settings.desiredSleepDuration))です。今夜の目標は後から設定できます。"
    }

    private var animatedSheep: some View {
        ZStack {
            Image(sheepAssetName)
                .resizable()
                .scaledToFit()
                .frame(height: 168)
                .scaleEffect(reduceMotion ? 1 : (sheepAnimating ? sheepScale : 0.97))
                .rotationEffect(.degrees(reduceMotion ? 0 : (sheepAnimating ? sheepRotation : -sheepRotation)))
                .offset(y: reduceMotion ? 0 : (sheepAnimating ? sheepOffset : -2))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: sheepAnimationDuration).repeatForever(autoreverses: true),
                    value: sheepAnimating
                )
            if vitality == .resting {
                restingEyeShadows
            } else if vitality == .radiant || vitality == .lively {
                sleepingMarks
            }
        }
        .accessibilityLabel("羊は\(vitality.displayName)状態です")
    }

    private var sleepingMarks: some View {
        Text("Zzz")
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .shadow(color: .blue.opacity(0.35), radius: 4, y: 2)
            .offset(x: 64, y: reduceMotion ? -72 : (sheepAnimating ? -84 : -68))
            .opacity(reduceMotion ? 0.9 : (sheepAnimating ? 1 : 0.62))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: sheepAnimating
            )
            .accessibilityHidden(true)
    }

    private var restingEyeShadows: some View {
        HStack(spacing: 22) {
            Capsule()
                .fill(.purple.opacity(0.32))
                .frame(width: 24, height: 8)
                .rotationEffect(.degrees(10))
            Capsule()
                .fill(.purple.opacity(0.32))
                .frame(width: 24, height: 8)
                .rotationEffect(.degrees(-10))
        }
        .offset(x: -7, y: 0)
        .blur(radius: 0.5)
        .accessibilityHidden(true)
    }

    private var landscapeTint: some View {
        LinearGradient(
            colors: [
                landscape.mood == .cloudy ? Color.gray.opacity(0.34) : .clear,
                period == .night ? Color.indigo.opacity(0.22) : .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func weeklyGoalCard(_ goal: WeeklyGoal) -> some View {
        GroupBox("今週の目標") {
            VStack(alignment: .leading, spacing: 10) {
                Text(goal.kind.displayName).font(.headline)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(goal.completedCount) / \(goal.targetCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("回").foregroundStyle(.secondary)
                    Spacer()
                    Text("残り\(dependencies.weeklyGoalProgressService.remainingDays(weekStart: goal.weekStart))日")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: goal.progress)
                    .accessibilityLabel("週間目標の進捗")
                    .accessibilityValue("\(goal.completedCount)回、目標\(goal.targetCount)回")
            }
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
            try prepareWeeklyGoalIfNeeded()
            try refreshWeeklyGoalIfNeeded()
            safetyGuidance = dependencies.safetyGuidanceService.guidance(
                records: records, dismissedAt: preferenceData.safetyGuidanceDismissedAt
            )
        } catch { loadError = error.localizedDescription }
    }

    private func refreshWeeklyGoalIfNeeded() throws {
        guard let existing = preferenceData.weeklyGoal else { return }
        let latestGoal = try dependencies.sleepGoalRepository.goals().first
        let progress = try dependencies.weeklyGoalProgressService.progress(
            kind: existing.kind,
            targetCount: existing.targetCount,
            weekStart: existing.weekStart,
            records: records,
            settings: settings,
            latestGoal: latestGoal
        )
        let updated = try WeeklyGoal(
            id: existing.id,
            kind: existing.kind,
            weekStart: existing.weekStart,
            targetCount: existing.targetCount,
            completedCount: progress.completedCount
        )
        preferenceData.weeklyGoal = updated
        if updated.completedCount >= updated.targetCount {
            preferenceData.rewardedWeeklyGoalIDs.insert(updated.id)
        }
        try dependencies.preferences.save(preferenceData)
    }

    private func prepareWeeklyGoalIfNeeded() throws {
        let today = try dependencies.dateTimeService.sleepDay(
            for: now,
            timeZoneIdentifier: TimeZone.current.identifier
        )
        let monday = try dependencies.weeklyGoalProgressService.mondayStart(containing: now)

        if let existing = preferenceData.weeklyGoal {
            if preferenceData.weeklyGoalFirstConfiguredAt == nil {
                preferenceData.weeklyGoalFirstConfiguredAt = now
                try dependencies.preferences.save(preferenceData)
            }
            let nextMonday = try dependencies.weeklyGoalProgressService.nextMonday(after: existing.weekStart)
            if today >= nextMonday {
                preferenceData.weeklyGoal = nil
                proposedWeeklyGoalStart = monday
                try dependencies.preferences.save(preferenceData)
                if !weeklyGoalPromptDismissedForSession { showingWeeklyGoal = true }
            }
            return
        }

        proposedWeeklyGoalStart = preferenceData.weeklyGoalFirstConfiguredAt == nil ? today : monday
        if !weeklyGoalPromptDismissedForSession { showingWeeklyGoal = true }
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes % 60 == 0 ? "\(minutes / 60)時間" : "\(minutes / 60)時間\(minutes % 60)分"
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
    var accentColor: Color {
        switch self {
        case .morning: .orange
        case .daytime: .cyan
        case .evening: .purple
        case .night: .indigo
        }
    }
    var titleGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.62), .mint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
