import SwiftUI

struct HomeView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    var onSettingsChanged: (UserSettings) -> Void = { _ in }
    var onResetAllData: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()
    @State private var recordingRoute: HomeRecordingRoute?
    @State private var showingRecordDayChoices = false
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
    @State private var landscapeCardWidth: CGFloat = 0

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
                        .frame(height: 72)
                        .accessibilityLabel("NemuChart")
                    if let weeklyGoal = preferenceData.weeklyGoal {
                        weeklyGoalCard(weeklyGoal)
                    }
                    greetingHeader
                    landscapeCard
                    if let safetyGuidance { safetyCard(safetyGuidance) }
                    Button {
                        showingRecordDayChoices = true
                    } label: {
                        Label("記録する", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    if period == .morning {
                        if hasRecordForCurrentSleepDay {
                            Label("今日の睡眠日は記録済みです。修正は「記録する」から今日を選んでください。", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Text("前夜の睡眠を、覚えている範囲で記録しましょう。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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
        .confirmationDialog("記録する日を選んでください", isPresented: $showingRecordDayChoices, titleVisibility: .visible) {
            ForEach(recordDayChoices) { choice in
                Button(choice.displayName) { openRecording(for: choice) }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(item: $recordingRoute) { route in
            SleepRecordFlow(
                repository: dependencies.sleepRecordRepository,
                scoringService: dependencies.scoringService,
                settings: settings,
                feedbackService: dependencies.feedbackService,
                goalRepository: dependencies.sleepGoalRepository,
                preferences: dependencies.preferences,
                notificationService: dependencies.notificationService,
                initialRecord: route.initialRecord,
                initialDraft: route.initialDraft,
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
        landscapeCardContent(isCompact: landscapeCardWidth == 0 || landscapeCardWidth < 430)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: LandscapeCardWidthPreferenceKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(LandscapeCardWidthPreferenceKey.self) { width in
                landscapeCardWidth = width
            }
    }

    private func landscapeCardContent(isCompact: Bool) -> some View {
        ZStack {
            Image("sheep-landscape")
                .resizable()
                .scaledToFill()
                .overlay(landscapeTint)
                .accessibilityHidden(true)
            VStack(spacing: isCompact ? 10 : 14) {
                HStack {
                    Image(systemName: period.symbol)
                    Spacer()
                    Image(systemName: landscape.mood.symbol)
                }
                .font(.title)
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .accessibilityHidden(true)
                if isCompact {
                    animatedSheep(height: 150, includesTerrain: false)
                    Spacer(minLength: 0)
                    compactLandscapeSummary
                } else {
                    animatedSheep(height: 168, includesTerrain: true)
                    regularLandscapeSummary
                }
            }
            .padding(isCompact ? 14 : 16)
        }
        .frame(height: isCompact ? 430 : 360)
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
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var growthSummary: some View {
        VStack(alignment: .leading) {
            Text("成長").font(.caption).foregroundStyle(.secondary)
            Text("\(growth.stage.displayName)・\(growth.points.value) pt").bold()
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
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
    private var recordDayChoices: [HomeRecordDayChoice] { [.today, .yesterday, .twoDaysAgo] }

    private var sleepDurationGuidance: String {
        if settings.sleepDurationPreference == .inferred {
            return "快眠の基準は記録から推定中です。いまは \(durationText(settings.desiredSleepDuration))を暫定の目安にしています。"
        }
        return "快眠の基準は \(durationText(settings.desiredSleepDuration))です。今夜の目標は後から設定できます。"
    }

    private var regularLandscapeSummary: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    sheepStateSummary
                    growthSummary
                }
                VStack(alignment: .leading, spacing: 8) {
                    sheepStateSummary
                    growthSummary
                }
            }
            weeklyProgressSummary
        }
        .frame(maxWidth: .infinity)
    }

    private var compactLandscapeSummary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                sheepStateSummary
                growthSummary
            }
            weeklyProgressSummary
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyProgressSummary: some View {
        ProgressView(value: Double(weeklyMetrics?.recordedDayCount ?? 0), total: 7) {
            Text("今週の記録 \(weeklyMetrics?.recordedDayCount ?? 0) / 7日")
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .tint(.white)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func animatedSheep(height: CGFloat, includesTerrain: Bool) -> some View {
        ZStack(alignment: .bottom) {
            if includesTerrain { sheepTerrain }
            Image(sheepAssetName)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .scaleEffect(reduceMotion ? 1 : (sheepAnimating ? sheepScale : 0.97))
                .rotationEffect(.degrees(reduceMotion ? 0 : (sheepAnimating ? sheepRotation : -sheepRotation)))
                .offset(y: (includesTerrain ? -20 : 0) + (reduceMotion ? 0 : (sheepAnimating ? sheepOffset : -2)))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: sheepAnimationDuration).repeatForever(autoreverses: true),
                    value: sheepAnimating
                )
            if vitality == .resting {
                restingEyeShadows
                    .offset(y: (includesTerrain ? -20 : 0) + (reduceMotion ? 0 : (sheepAnimating ? sheepOffset : -2)))
            } else if vitality == .radiant || vitality == .lively {
                sleepingMarks
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: includesTerrain ? 232 : 164)
        .clipped()
        .accessibilityLabel("羊は\(vitality.displayName)状態です")
    }

    private var sheepTerrain: some View {
        ZStack(alignment: .bottom) {
            MountainShape()
                .fill(.teal.opacity(0.28))
                .frame(width: 250, height: 96)
                .offset(x: -78, y: -54)
            MountainShape()
                .fill(.mint.opacity(0.34))
                .frame(width: 210, height: 82)
                .offset(x: 86, y: -44)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0.74), .mint.opacity(0.6), .cyan.opacity(0.35)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 360, height: 112)
                .offset(y: 36)
            Ellipse()
                .fill(.white.opacity(0.18))
                .frame(width: 190, height: 36)
                .offset(y: 2)
        }
        .accessibilityHidden(true)
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

    private func openRecording(for choice: HomeRecordDayChoice) {
        do {
            let sleepDay = try sleepDay(for: choice)
            if let existing = latestRecord(for: sleepDay) {
                recordingRoute = HomeRecordingRoute(initialRecord: existing)
            } else {
                recordingRoute = HomeRecordingRoute(initialDraft: try draft(for: sleepDay))
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func latestRecord(for sleepDay: SleepDay) -> SleepRecord? {
        records
            .filter { $0.sleepDay.key == sleepDay.key }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private func sleepDay(for choice: HomeRecordDayChoice) throws -> SleepDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(byAdding: .day, value: -choice.daysAgo, to: now) else {
            throw DateTimeError.invalidDateComponents
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            throw DateTimeError.invalidDateComponents
        }
        return try SleepDay(year: year, month: month, day: day, timeZoneIdentifier: TimeZone.current.identifier)
    }

    private func draft(for sleepDay: SleepDay) throws -> SleepRecordDraft {
        let service = DateTimeService()
        let targetWake = try service.date(on: sleepDay, localTime: settings.standardWakeTime, dayOffset: 0)
        let wake = min(targetWake, now)
        let sleepStart = wake.addingTimeInterval(-settings.desiredSleepDuration)
        var draft = SleepRecordDraft(now: wake)
        draft.wakeTime = wake
        draft.sleepClock = sleepStart
        return draft
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

private struct HomeRecordingRoute: Identifiable {
    let id = UUID()
    var initialRecord: SleepRecord?
    var initialDraft: SleepRecordDraft?
}

private struct LandscapeCardWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum HomeRecordDayChoice: Int, CaseIterable, Identifiable {
    case today
    case yesterday
    case twoDaysAgo

    var id: Self { self }
    var daysAgo: Int { rawValue }

    var displayName: String {
        switch self {
        case .today: "今日"
        case .yesterday: "昨日"
        case .twoDaysAgo: "一昨日"
        }
    }
}

private struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
