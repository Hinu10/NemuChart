import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencies
    @State private var settings: UserSettings?
    @State private var didLoad = false
    @State private var errorMessage: String?
    @State private var storeUpdateURL: URL?
    @State private var versionComparison: (current: String, latest: String)?
    @State private var showingWhatsNew = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if !didLoad {
                VStack(spacing: 20) {
                    Image("NemuChartLogoCropped")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 330)
                        .accessibilityLabel("ねむちゃーと")
                    ProgressView("読み込んでいます")
                }
                .padding(28)
            } else if let settings, settings.hasCompletedOnboarding {
                HomeView(
                    dependencies: dependencies,
                    settings: settings,
                    onSettingsChanged: { self.settings = $0 },
                    onResetAllData: { self.settings = nil },
                    suppressesAutomaticPrompts: showingWhatsNew || storeUpdateURL != nil
                )
            } else {
                OnboardingView(repository: dependencies.userSettingsRepository) { saved in
                    settings = saved
                }
            }
        }
        .task {
            await loadSettings()
            await checkVersion()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView(version: WhatsNew.current) { showingWhatsNew = false }
        }
        .alert("新しいバージョンがあります", isPresented: Binding(
            get: { storeUpdateURL != nil && !showingWhatsNew },
            set: { if !$0 { storeUpdateURL = nil } }
        )) {
            Button("アップデートする") {
                if let storeUpdateURL { openURL(storeUpdateURL) }
                storeUpdateURL = nil
            }
            Button("あとで", role: .cancel) { storeUpdateURL = nil }
        } message: {
            if let versionComparison {
                Text("お使いのバージョンは \(versionComparison.current)、App Store の最新版は \(versionComparison.latest) です。新機能や改善を利用するにはアップデートをおすすめします。")
            }
        }
        .alert("読み込みエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("再試行") { Task { await loadSettings() } }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadSettings() async {
        didLoad = false
        let skipsDelay = ProcessInfo.processInfo.environment["NEMUCHART_UI_TESTING"] == "1"
        async let minimumDisplay: Void = waitForMinimumDisplay(skipsDelay: skipsDelay)
        do {
            settings = try dependencies.userSettingsRepository.load()
            rescheduleWindDownIfNeeded()
            // ホームが週間目標の画面を出す前に決めておく。
            prepareWhatsNew()
            _ = await minimumDisplay
            didLoad = true
        } catch {
            _ = await minimumDisplay
            errorMessage = error.localizedDescription
            didLoad = true
        }
    }

    private func waitForMinimumDisplay(skipsDelay: Bool) async {
        guard !skipsDelay else { return }
        try? await Task.sleep(for: .seconds(2))
    }

    private var currentVersion: String? {
        guard ProcessInfo.processInfo.environment["NEMUCHART_UI_TESTING"] != "1" else { return nil }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// 以前の版で「今夜の目標」を開いた時刻から予約された通知を、設定から決めた時刻に置き換える。
    private func rescheduleWindDownIfNeeded() {
        guard let settings, settings.notificationPreference.isEnabledInApp else { return }
        let bedTime = WindDownNotificationPlanner().bedTime(wake: settings.standardWakeTime, sleepDuration: settings.desiredSleepDuration)
        Task { try? await dependencies.notificationService.scheduleWindDown(before: bedTime) }
    }

    /// アップデート後の初回起動なら「今回の変更」を出す。
    private func prepareWhatsNew() {
        guard let current = currentVersion else { return }
        let defaults = UserDefaults.standard
        let key = "NemuChart.lastLaunchedVersion"
        let previous = defaults.string(forKey: key)
        // 1.0 には起動したバージョンを残す仕組みがないため、記録がなくても初回設定を終えた人はアップデートした人とみなす。
        let isUpdate = previous.map { $0 != current } ?? (settings?.hasCompletedOnboarding == true)
        if isUpdate && current == WhatsNew.current.version { showingWhatsNew = true }
        defaults.set(current, forKey: key)
    }

    /// App Store の最新版がお使いの版より新しければ、1日1回まで案内する。
    private func checkVersion() async {
        guard let current = currentVersion else { return }
        let defaults = UserDefaults.standard
        guard let listing = await storeListing(),
              listing.version.compare(current, options: .numeric) == .orderedDescending,
              !((defaults.object(forKey: Self.lastUpdatePromptKey) as? Date).map(Calendar.current.isDateInToday) ?? false),
              let storeURL = URL(string: listing.trackViewUrl) else { return }
        defaults.set(Date(), forKey: Self.lastUpdatePromptKey)
        versionComparison = (current, listing.version)
        storeUpdateURL = storeURL
    }

    private static let lastUpdatePromptKey = "NemuChart.lastUpdatePromptDate"

    private func storeListing() async -> StoreLookup.Listing? {
        #if DEBUG
        // デモや確認用に、App Store に新しい版がある状態を起動引数で再現できるようにする。
        if let version = UserDefaults.standard.string(forKey: "NemuChartDemoStoreVersion") {
            return StoreLookup.Listing(version: version, trackViewUrl: "https://apps.apple.com/jp/app/id0")
        }
        #endif
        guard let bundle = Bundle.main.bundleIdentifier,
              var components = URLComponents(string: "https://itunes.apple.com/lookup") else { return nil }
        components.queryItems = [URLQueryItem(name: "bundleId", value: bundle), URLQueryItem(name: "country", value: "jp")]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(StoreLookup.self, from: data) else { return nil }
        return response.results.first
    }
}

private struct StoreLookup: Decodable {
    struct Listing: Decodable { let version: String; let trackViewUrl: String }
    let results: [Listing]
}
