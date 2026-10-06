import Combine
import SwiftUI
import UIKit

struct HomeView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    var onSettingsChanged: (UserSettings) -> Void = { _ in }
    var onResetAllData: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var now = Date()
    @State private var recordingRoute: HomeRecordingRoute?
    @State private var showingRecordDayChoices = false
    @State private var showingHistory = false
    @State private var showingWeekly = false
    @State private var showingWeeklyGoal = false
    @State private var proposedWeeklyGoalStart: SleepDay?
    @State private var weeklyGoalPromptDismissedForSession = false
    @State private var showingSettings = false
    @State private var showingCollection = false
    @State private var records: [SleepRecord] = []
    @State private var scores: [DailySleepScore] = []
    @State private var weeklyMetrics: WeeklyMetrics?
    @State private var preferenceData = AppPreferenceData()
    @State private var safetyGuidance: SafetyGuidance?
    @State private var loadError: String?
    @State private var carouselSelection = HomeCarouselCard.greeting
    private let carouselTimer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    private var period: HomeTimeOfDay { TimeOfDayPolicy().period(at: now) }
    private var vitality: Vitality { dependencies.vitalityService.vitality(scores: scores) }
    private var growth: SheepGrowthSummary {
        dependencies.growthService.summary(
            earnings: dependencies.growthService.earnings(records: records, scores: scores, goals: (try? dependencies.sleepGoalRepository.goals()) ?? []),
            completedWeeklyGoalIDs: Array(preferenceData.rewardedWeeklyGoalIDs)
        )
    }

    var body: some View {
        GeometryReader { rootProxy in
            let isShortPortrait = rootProxy.size.height < 720
            let isMediumPortrait = rootProxy.size.height < 820
            let contentSpacing = isShortPortrait ? CGFloat(10) : isMediumPortrait ? CGFloat(14) : CGFloat(18)
            let contentPadding = isShortPortrait ? CGFloat(12) : isMediumPortrait ? CGFloat(14) : CGFloat(16)

            NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    Image("NemuChartLogoCropped")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: isShortPortrait ? 42 : isMediumPortrait ? 50 : 56)
                        .accessibilityLabel("ねむちゃーと")
                    topSummaryCarousel(height: isShortPortrait ? 130 : isMediumPortrait ? 158 : 176)
                    landscapeCard(viewportSize: rootProxy.size)
                    if let safetyGuidance { safetyCard(safetyGuidance) }
                    Button {
                        showingRecordDayChoices = true
                    } label: {
                        Label("記録する", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button {
                        showingWeekly = true
                    } label: {
                        Label("7日間の分析を見る", systemImage: "chart.bar.xaxis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("過去の記録", systemImage: "clock.arrow.circlepath") { showingHistory = true }
                    Button("コレクション", systemImage: "square.grid.2x2") { showingCollection = true }
                    Button("設定", systemImage: "gearshape") { showingSettings = true }
                        .accessibilityIdentifier("homeSettingsButton")
                }
            }
        }
        }
        .confirmationDialog("記録する日を選んでください", isPresented: $showingRecordDayChoices, titleVisibility: .visible) {
            ForEach(recordDayChoices) { choice in
                Button(choice.displayName) { openRecording(for: choice) }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMorningRecord)) { _ in
            openRecordingFromMorning()
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
        .sheet(isPresented: $showingCollection) {
            SheepCollectionView(
                growthPoints: growth.points.value,
                unlockedIDs: preferenceData.unlockedContentIDs,
                sheepAssetName: sheepAssetName
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
                settings: settings,
                preferences: dependencies.preferences
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
        .sheet(isPresented: $showingSettings, onDismiss: loadDashboard) {
            SettingsView(
                dependencies: dependencies,
                settings: settings,
                onSaved: onSettingsChanged,
                onDeleteAll: onResetAllData
            )
        }
        .task {
            loadDashboard()
            if UserDefaults.standard.bool(forKey: "NemuChart.pendingMorningRecord") {
                openRecordingFromMorning()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                weeklyGoalPromptDismissedForSession = false
                now = Date()
                loadDashboard()
                if UserDefaults.standard.object(forKey: "NemuChart.alarmWakeTime") != nil ||
                    UserDefaults.standard.bool(forKey: "NemuChart.pendingMorningRecord") {
                    openRecordingFromMorning()
                }
            }
        }
        .alert("データを読み込めませんでした", isPresented: Binding(
            get: { loadError != nil }, set: { if !$0 { loadError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(loadError ?? "") }
        .onReceive(carouselTimer) { _ in advanceCarousel() }
    }

    private func topSummaryCarousel(height: CGFloat) -> some View {
        let cards = availableCarouselCards
        return VStack(spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                ForEach(cards) { card in
                    carouselCard(card)
                }
            } else {
                TabView(selection: $carouselSelection) {
                    ForEach(cards) { card in
                        carouselCard(card)
                            .tag(card)
                            .padding(.horizontal, 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: height)
                carouselPageButtons(cards)
            }
        }
        .onAppear { normalizeCarouselSelection(for: cards) }
        .onChange(of: preferenceData.weeklyGoal?.id) { _, _ in
            normalizeCarouselSelection(for: availableCarouselCards)
        }
        .accessibilityElement(children: .contain)
    }

    private var availableCarouselCards: [HomeCarouselCard] {
        return [.weeklyGoal, .greeting, .latestScore, .guidance]
    }

    @ViewBuilder
    private func carouselCard(_ card: HomeCarouselCard) -> some View {
        switch card {
        case .weeklyGoal:
            if let weeklyGoal = preferenceData.weeklyGoal {
                weeklyGoalCard(weeklyGoal)
            } else {
                weeklyGoalPlaceholderCard
            }
        case .greeting:
            greetingHeader
        case .latestScore:
            latestScoreCard
        case .guidance:
            todayGuidanceCard
        }
    }

    private func carouselPageButtons(_ cards: [HomeCarouselCard]) -> some View {
        HStack(spacing: 10) {
            ForEach(cards) { card in
                Button {
                    if reduceMotion {
                        carouselSelection = card
                    } else {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            carouselSelection = card
                        }
                    }
                } label: {
                    Circle()
                        .fill(card == carouselSelection ? Color.accentColor : Color.secondary.opacity(0.28))
                        .frame(width: card == carouselSelection ? 10 : 8, height: card == carouselSelection ? 10 : 8)
                        .overlay {
                            Circle()
                                .stroke(Color.accentColor.opacity(card == carouselSelection ? 0.28 : 0), lineWidth: 5)
                        }
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel("\(card.accessibilityTitle)へ移動")
                .accessibilityAddTraits(card == carouselSelection ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func advanceCarousel() {
        let cards = availableCarouselCards
        guard cards.count > 1, !reduceMotion, !dynamicTypeSize.isAccessibilitySize,
              !UIAccessibility.isVoiceOverRunning else { return }
        let currentIndex = cards.firstIndex(of: carouselSelection) ?? 0
        withAnimation(.easeInOut(duration: 0.45)) {
            carouselSelection = cards[(currentIndex + 1) % cards.count]
        }
    }

    private func normalizeCarouselSelection(for cards: [HomeCarouselCard]) {
        guard let first = cards.first else { return }
        if !cards.contains(carouselSelection) {
            carouselSelection = first
        }
    }

    private func landscapeCard(viewportSize: CGSize) -> some View {
        landscapeCardContent(viewportSize: viewportSize)
        .frame(maxWidth: .infinity)
    }

    private func landscapeCardContent(viewportSize: CGSize) -> some View {
        let cardWidth = viewportSize.width - 32
        let cardHeight = HomeLandscapeLayout.cardHeight(width: cardWidth, viewportHeight: viewportSize.height)
        let isTight = viewportSize.height < 720
        let artworkHeight = HomeLandscapeLayout.artworkHeight(cardHeight: cardHeight, width: cardWidth)
        return VStack(spacing: 0) {
            SheepSceneArtwork(
                sheepAssetName: sheepAssetName,
                backgroundID: automaticBackground?.id,
                effectID: automaticEffect?.id,
                accessoryIDs: unlockedSceneDecorations,
                animate: !reduceMotion && ProcessInfo.processInfo.environment["NEMUCHART_UI_TESTING"] != "1",
                fadeIntoStatus: true,
                nightMode: period == .night
            )
            .frame(height: artworkHeight)
            .accessibilityLabel(sceneAccessibilityLabel)
            Spacer(minLength: 0)
            compactLandscapeSummary(isTight: isTight)
                .padding(.horizontal, HomeLandscapeLayout.contentPadding)
                .padding(.bottom, HomeLandscapeLayout.contentPadding)
        }
        .frame(minHeight: cardHeight)
        .background(HomeLandscapeLayout.statusBackground)
        .clipShape(HomeLandscapeLayout.cardShape)
        .overlay(HomeLandscapeLayout.cardShape.stroke(.white.opacity(0.42), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeLandscapeCard")
    }

    private var greetingHeader: some View {
        ViewThatFits(in: .horizontal) {
            greetingHeaderContent(isCompact: false)
            greetingHeaderContent(isCompact: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private func greetingHeaderContent(isCompact: Bool) -> some View {
        HStack(alignment: .top, spacing: isCompact ? 8 : 14) {
            Image(systemName: period.symbol)
                .font(.title)
                .foregroundStyle(period.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(period.title)
                    .font(.system(isCompact ? .title : .largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(period.titleGradient)
                    .shadow(color: period.accentColor.opacity(0.22), radius: 5, y: 2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(period.message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sheepStateSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("元気度")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(HomeLandscapeLayout.headingColor)
            Text(vitality.displayName)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(HomeLandscapeLayout.bodyColor)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .fixedSize(horizontal: false, vertical: true)
        .landscapeStatusCard()
    }

    private var growthSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("成長")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(HomeLandscapeLayout.headingColor)
            Text("\(growth.stage.displayName)・\(growth.points.value) pt")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(HomeLandscapeLayout.bodyColor)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .fixedSize(horizontal: false, vertical: true)
        .landscapeStatusCard()
    }

    private var latestScoreCard: some View {
        GroupBox("直近の点数") {
            if let latest = latestScoredRecord {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(latest.record.sleepDay.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(latest.score.total)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            Text("点")
                                .foregroundStyle(.secondary)
                        }
                        Text(scoreQualityText(latest.score.total))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    scoreDifferenceView(latest)
                }
            } else {
                Text("記録を保存すると、直近の点数と前回からの変化が表示されます。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var todayGuidanceCard: some View {
        GroupBox(todayGuidanceTitle) {
            VStack(alignment: .leading, spacing: 10) {
                if hasRecordForCurrentSleepDay {
                    Label("今日の記録は完了しました", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("修正は「記録する」から今日を選んでください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("今日はまだ記録していません")
                        .font(.headline)
                    Label(todayGuidanceHeadline, systemImage: todayGuidanceSymbol)
                        .font(.headline)
                        .foregroundStyle(period.accentColor)
                    Text(todayGuidanceMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func scoreDifferenceView(_ latest: HomeScoredRecord) -> some View {
        if let previous = previousScoredRecord(before: latest.record) {
            let difference = latest.score.total - previous.score.total
            VStack(alignment: .trailing, spacing: 6) {
                Label(
                    difference == 0 ? "±0点" : "\(difference > 0 ? "+" : "")\(difference)点",
                    systemImage: scoreDifferenceSymbol(difference)
                )
                .font(.headline)
                .foregroundStyle(scoreDifferenceColor(difference))
                Text("前回入力日から")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("前回比較なし")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        case .drowsy: "sheep-resting"
        case .resting: "sheep-resting"
        case .calm: "sheep-calm"
        case .lively: "sheep-lively"
        case .radiant: "sheep-radiant"
        }
    }

    private var unlockedSceneDecorations: Set<String> {
        Set(SheepCollectible.all.filter {
            $0.category == .accessory && preferenceData.unlockedContentIDs.contains($0.id)
        }.map(\.id))
    }

    private var sceneAccessibilityLabel: String {
        let visibleNames = [automaticBackground?.name, automaticEffect?.name].compactMap { $0 }
            + SheepCollectible.all.filter { unlockedSceneDecorations.contains($0.id) }.map(\.name)
        return (["ひつじの景色"] + visibleNames).joined(separator: "、")
    }

    private var automaticBackground: SheepCollectible? {
        let unlocked = SheepCollectible.all.filter {
            $0.category == .background && preferenceData.unlockedContentIDs.contains($0.id)
        }
        guard !unlocked.isEmpty else { return nil }
        let preferred: String = period == .night ? "stars" : period == .morning ? "morning" : "sunset"
        if let match = unlocked.first(where: { $0.id == preferred }) { return match }
        return unlocked[(Calendar.current.component(.day, from: now) / 2) % unlocked.count]
    }

    private var automaticEffect: SheepCollectible? {
        let unlocked = SheepCollectible.all.filter {
            $0.category == .effect && preferenceData.unlockedContentIDs.contains($0.id)
        }
        guard !unlocked.isEmpty else { return nil }
        return unlocked[Calendar.current.component(.day, from: now) % unlocked.count]
    }

    private var recordDayChoices: [HomeRecordDayChoice] { [.today, .yesterday, .twoDaysAgo] }

    private var sleepDurationGuidance: String {
        if settings.sleepDurationPreference == .inferred {
            return "快眠の基準は記録から推定中です。いまは \(durationText(settings.desiredSleepDuration))を暫定の目安にしています。"
        }
        return "快眠の基準は \(durationText(settings.desiredSleepDuration))です。今夜の目標は後から設定できます。"
    }

    private var todayGuidanceTitle: String {
        switch period {
        case .morning: "今日の記録"
        case .daytime, .evening: "今日の目安"
        case .night: "休息の目安"
        }
    }

    private var todayGuidanceHeadline: String {
        switch period {
        case .morning: "前夜の睡眠を記録"
        case .daytime: "今夜の目安"
        case .evening: "そろそろ休む準備"
        case .night: "いまは休息を優先"
        }
    }

    private var todayGuidanceMessage: String {
        switch period {
        case .morning:
            return "前夜の睡眠を、覚えている範囲で記録しましょう。"
        case .daytime, .evening:
            return sleepDurationGuidance
        case .night:
            return "記録は明日の朝に。いまは端末を置いて、ゆっくり休みましょう。"
        }
    }

    private var todayGuidanceSymbol: String {
        switch period {
        case .morning: "square.and.pencil"
        case .daytime: "target"
        case .evening: "bed.double.fill"
        case .night: "moon.zzz.fill"
        }
    }

    private func compactLandscapeSummary(isTight: Bool) -> some View {
        VStack(spacing: isTight ? 7 : HomeLandscapeLayout.cardSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: isTight ? 7 : HomeLandscapeLayout.cardSpacing) {
                    sheepStateSummary
                    growthSummary
                }
                VStack(spacing: isTight ? 7 : HomeLandscapeLayout.cardSpacing) {
                    sheepStateSummary
                    growthSummary
                }
            }
            weeklyProgressSummary(isTight: isTight)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
    }

    private func weeklyProgressSummary(isTight: Bool) -> some View {
        let recordedDayCount = weeklyMetrics?.recordedDayCount ?? 0
        let progress = min(max(CGFloat(recordedDayCount) / 7, 0), 1)

        return VStack(alignment: .leading, spacing: isTight ? 8 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("今週の記録")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(HomeLandscapeLayout.headingColor)
                Spacer(minLength: 8)
                Text("\(recordedDayCount) / 7日")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(HomeLandscapeLayout.bodyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.34))
                    if progress > 0 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.96), Color.mint.opacity(0.78)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(proxy.size.width, proxy.size.width * progress))
                    }
                }
            }
            .frame(height: 9)
        }
        .padding(.horizontal, HomeLandscapeLayout.statusCardPadding)
        .padding(.vertical, isTight ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: HomeLandscapeLayout.statusCardShape)
        .overlay(
            HomeLandscapeLayout.statusCardShape
                .stroke(.white.opacity(0.36), lineWidth: 1)
        )
    }

    private func weeklyGoalCard(_ goal: WeeklyGoal) -> some View {
        GroupBox("今週の目標") {
            VStack(alignment: .leading, spacing: 10) {
                Text(weeklyGoalTitle(for: goal)).font(.headline)
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

    private func weeklyGoalTitle(for goal: WeeklyGoal) -> String {
        guard goal.kind == .custom else { return goal.kind.displayName }
        let customText = preferenceData.customWeeklyGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return customText.isEmpty ? goal.kind.displayName : customText
    }

    private var weeklyGoalPlaceholderCard: some View {
        GroupBox("今週の目標") {
            VStack(alignment: .leading, spacing: 10) {
                Label("目標を設定できます", systemImage: "flag.checkered")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("今週の記録目標を決めると、ここで進捗を確認できます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showingWeeklyGoal = true
                } label: {
                    Label("目標を設定", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            try reconcileWeeklyGoalHistory()
            let entries = dependencies.growthService.earnings(records: records, scores: scores, goals: try dependencies.sleepGoalRepository.goals())
            preferenceData.growthEarnings = Dictionary(uniqueKeysWithValues: entries.map { ($0.recordID, $0) })
            preferenceData.unlockedContentIDs.formUnion(SheepCollectible.all.filter { growth.points.value >= $0.requiredGrowth }.map(\.id))
            try dependencies.preferences.save(preferenceData)
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
            completedCount: existing.kind == .custom
                ? (preferenceData.customWeeklyGoalCompleted ? existing.targetCount : 0)
                : progress.completedCount
        )
        preferenceData.weeklyGoal = updated
        preferenceData.weeklyGoalHistory.removeAll { $0.id == updated.id }
        preferenceData.weeklyGoalHistory.append(updated)
        if updated.completedCount >= updated.targetCount {
            preferenceData.rewardedWeeklyGoalIDs.insert(updated.id)
        } else {
            preferenceData.rewardedWeeklyGoalIDs.remove(updated.id)
        }
        try dependencies.preferences.save(preferenceData)
    }

    private func reconcileWeeklyGoalHistory() throws {
        let latestGoal = try dependencies.sleepGoalRepository.goals().first
        var updatedHistory: [WeeklyGoal] = []
        for goal in preferenceData.weeklyGoalHistory {
            let completed: Int
            if goal.kind == .custom {
                completed = goal.completedCount
            } else {
                let progress = try dependencies.weeklyGoalProgressService.progress(
                    kind: goal.kind, targetCount: goal.targetCount, weekStart: goal.weekStart,
                    records: records, settings: settings, latestGoal: latestGoal
                )
                completed = progress.completedCount
            }
            let updated = try WeeklyGoal(id: goal.id, kind: goal.kind, weekStart: goal.weekStart,
                                         targetCount: goal.targetCount, completedCount: completed)
            updatedHistory.append(updated)
            if completed >= goal.targetCount { preferenceData.rewardedWeeklyGoalIDs.insert(goal.id) }
            else { preferenceData.rewardedWeeklyGoalIDs.remove(goal.id) }
            if preferenceData.weeklyGoal?.id == goal.id { preferenceData.weeklyGoal = updated }
        }
        preferenceData.weeklyGoalHistory = updatedHistory
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

    private var latestScoredRecord: HomeScoredRecord? {
        scoredRecords.sorted { $0.record.sleepDay > $1.record.sleepDay }.first
    }

    private var scoredRecords: [HomeScoredRecord] {
        records.compactMap { record in
            guard let score = try? dependencies.scoringService.score(record: record, settings: settings) else { return nil }
            return HomeScoredRecord(record: record, score: score)
        }
    }

    private func previousScoredRecord(before latest: SleepRecord) -> HomeScoredRecord? {
        scoredRecords
            .filter { $0.record.sleepDay < latest.sleepDay }
            .sorted { $0.record.sleepDay > $1.record.sleepDay }
            .first
    }

    private func scoreQualityText(_ score: Int) -> String {
        switch score {
        case 85...100: "とても良い目安"
        case 70..<85: "良い目安"
        case 50..<70: "見直しの余地あり"
        default: "休息を優先したい状態"
        }
    }

    private func scoreDifferenceSymbol(_ difference: Int) -> String {
        if difference > 0 { return "arrow.up.circle.fill" }
        if difference < 0 { return "arrow.down.circle.fill" }
        return "minus.circle.fill"
    }

    private func scoreDifferenceColor(_ difference: Int) -> Color {
        if difference > 0 { return .green }
        if difference < 0 { return .orange }
        return .secondary
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

    private func openRecordingFromMorning() {
        guard recordingRoute == nil else { return }
        UserDefaults.standard.removeObject(forKey: "NemuChart.pendingMorningRecord")
        let alarmWake = UserDefaults.standard.object(forKey: "NemuChart.alarmWakeTime") as? Date
        UserDefaults.standard.removeObject(forKey: "NemuChart.alarmWakeTime")
        guard let alarmWake else { openRecording(for: .today); return }
        do {
            let day = try sleepDay(for: .today)
            if let existing = latestRecord(for: day) {
                recordingRoute = HomeRecordingRoute(initialRecord: existing)
            } else {
                var draft = try draft(for: day)
                draft.wakeTime = alarmWake
                recordingRoute = HomeRecordingRoute(initialDraft: draft)
            }
        } catch { loadError = error.localizedDescription }
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
        draft.recordDate = wake
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
        case .drowsy: "かなり眠そう"
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

private struct HomeScoredRecord {
    let record: SleepRecord
    let score: DailySleepScore
}

private enum HomeCarouselCard: CaseIterable, Identifiable {
    case weeklyGoal
    case greeting
    case latestScore
    case guidance

    var id: Self { self }

    var accessibilityTitle: String {
        switch self {
        case .weeklyGoal: "今週の目標"
        case .greeting: "時間帯メッセージ"
        case .latestScore: "直近の点数"
        case .guidance: "今日の目安"
        }
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

private enum HomeLandscapeLayout {
    static let cornerRadius = CGFloat(22)
    static let contentPadding = CGFloat(12)
    static let cardSpacing = CGFloat(8)
    static let statusCardPadding = CGFloat(12)
    static let statusBackground = Color(red: 0.9, green: 0.95, blue: 0.99)
    static let headingColor = Color(red: 0.28, green: 0.38, blue: 0.54)
    static let bodyColor = Color(red: 0.12, green: 0.18, blue: 0.27)

    static func cardHeight(width: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let widthBasedHeight = width * 0.98
        let heightCap: CGFloat
        if viewportHeight < 700 {
            heightCap = 320
        } else if viewportHeight < 720 {
            heightCap = 340
        } else if viewportHeight < 820 {
            heightCap = 378
        } else {
            heightCap = 420
        }
        return min(max(widthBasedHeight, 316), heightCap)
    }

    static func artworkHeight(cardHeight: CGFloat, width: CGFloat) -> CGFloat {
        min(cardHeight * 0.47, max(width * 0.52, 176))
    }

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    static var statusCardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }
}

private struct LandscapeStatusCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, HomeLandscapeLayout.statusCardPadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: HomeLandscapeLayout.statusCardShape)
            .overlay(
                HomeLandscapeLayout.statusCardShape
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
    }
}

private extension View {
    func landscapeStatusCard() -> some View {
        modifier(LandscapeStatusCardModifier())
    }
}
