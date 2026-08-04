import SwiftUI

struct HomeView: View {
    let dependencies: AppDependencies
    let settings: UserSettings
    var onSettingsChanged: (UserSettings) -> Void = { _ in }
    var onResetAllData: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var carouselSelection = HomeCarouselCard.greeting
    private let carouselTimer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

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
                    Button("設定", systemImage: "gearshape") { showingSettings = true }
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
        .onReceive(carouselTimer) { _ in advanceCarousel() }
    }

    private func topSummaryCarousel(height: CGFloat) -> some View {
        let cards = availableCarouselCards
        return VStack(spacing: 8) {
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
                    withAnimation(.easeInOut(duration: 0.35)) {
                        carouselSelection = card
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
                .frame(width: 28, height: 28)
                .accessibilityLabel("\(card.accessibilityTitle)へ移動")
                .accessibilityAddTraits(card == carouselSelection ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func advanceCarousel() {
        let cards = availableCarouselCards
        guard cards.count > 1 else { return }
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
        GeometryReader { proxy in
            let cardHeight = HomeLandscapeLayout.cardHeight(
                width: proxy.size.width,
                viewportHeight: viewportSize.height
            )
            let isTight = viewportSize.height < 720
            let artworkHeight = HomeLandscapeLayout.artworkHeight(
                cardHeight: cardHeight,
                width: proxy.size.width
            )
            let sheepHeight = HomeLandscapeLayout.sheepHeight(
                cardHeight: cardHeight,
                viewportHeight: viewportSize.height
            )

            ZStack {
                landscapeBackdrop
                landscapeArtwork(height: artworkHeight)
                    .frame(maxHeight: .infinity, alignment: .top)

                VStack(spacing: isTight ? 7 : 9) {
                    Spacer(minLength: max(18, artworkHeight * 0.08))
                    animatedSheep(
                        height: sheepHeight,
                        includesTerrain: true,
                        canMove: true,
                        isTight: isTight
                    )
                    Spacer(minLength: 0)
                    compactLandscapeSummary(isTight: isTight)
                }
                .padding(.horizontal, HomeLandscapeLayout.contentPadding)
                .padding(.top, isTight ? 8 : 10)
                .padding(.bottom, HomeLandscapeLayout.contentPadding)
            }
            .clipShape(HomeLandscapeLayout.cardShape)
            .overlay(
                HomeLandscapeLayout.cardShape
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            )
        }
        .frame(height: HomeLandscapeLayout.cardHeight(width: viewportSize.width - 32, viewportHeight: viewportSize.height))
        .onAppear { sheepAnimating = true }
    }

    private func landscapeArtwork(height: CGFloat) -> some View {
        Image("sheep-landscape")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .top)
            .clipped()
            .overlay(landscapeTint)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .clear,
                        Color(red: 0.67, green: 0.88, blue: 0.82).opacity(0.44),
                        HomeLandscapeLayout.statusBackground.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(150, height * 0.48))
            }
            .accessibilityHidden(true)
    }

    private var landscapeBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.44, blue: 0.78),
                    Color(red: 0.46, green: 0.75, blue: 0.92),
                    Color(red: 0.99, green: 0.78, blue: 0.58),
                    Color(red: 0.75, green: 0.91, blue: 0.84),
                    HomeLandscapeLayout.statusBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.18),
                    Color.mint.opacity(0.22),
                    Color.white.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
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
                if period == .morning, hasRecordForCurrentSleepDay {
                    Label("今日の睡眠日は記録済みです", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("修正は「記録する」から今日を選んでください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
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
        case .resting: "sheep-resting"
        case .calm: "sheep-calm"
        case .lively: "sheep-lively"
        case .radiant: "sheep-radiant"
        }
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

    private func animatedSheep(height: CGFloat, includesTerrain: Bool, canMove: Bool, isTight: Bool = false) -> some View {
        ZStack(alignment: .bottom) {
            if includesTerrain { sheepTerrain }
            Image(sheepAssetName)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .offset(y: (includesTerrain ? -10 : 16) + (canMove && sheepAnimating ? -4 : 0))
                .animation(
                    canMove ? .easeInOut(duration: 3.8).repeatForever(autoreverses: true) : nil,
                    value: sheepAnimating
                )
            if vitality == .radiant || vitality == .lively {
                sleepingMarks
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: includesTerrain ? max(height + (isTight ? 32 : 40), isTight ? 148 : 164) : max(height + 28, 164))
        .accessibilityLabel("羊は\(vitality.displayName)状態です")
    }

    private var sheepTerrain: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let hillWidth = min(width * 1.04, 340)
            let shadowWidth = min(width * 0.38, 150)

            ZStack(alignment: .bottom) {
                MountainShape()
                    .fill(.teal.opacity(0.22))
                    .frame(width: min(width * 0.72, 230), height: 86)
                    .offset(x: -width * 0.18, y: -50)
                MountainShape()
                    .fill(.mint.opacity(0.28))
                    .frame(width: min(width * 0.62, 205), height: 76)
                    .offset(x: width * 0.2, y: -42)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.58), .mint.opacity(0.46), .cyan.opacity(0.24)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: hillWidth, height: 104)
                    .offset(y: 34)
                Ellipse()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: shadowWidth, height: 24)
                    .blur(radius: 8)
                    .offset(y: -1)
            }
        }
        .accessibilityHidden(true)
    }

    private var sleepingMarks: some View {
        Text("Zzz")
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .shadow(color: .blue.opacity(0.42), radius: 4, y: 2)
            .offset(x: 58, y: -82)
            .opacity(0.96)
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
        case 50..<70: "改善の余地あり"
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
    static let statusBackground = Color(red: 0.88, green: 0.96, blue: 0.91)
    static let headingColor = Color(red: 0.24, green: 0.42, blue: 0.38)
    static let bodyColor = Color(red: 0.12, green: 0.20, blue: 0.19)

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

    static func sheepHeight(cardHeight: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let base = cardHeight * 0.27
        let cap = viewportHeight < 720 ? CGFloat(102) : CGFloat(116)
        return min(max(base, 92), cap)
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
