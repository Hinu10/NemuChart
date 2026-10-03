import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencies
    @State private var settings: UserSettings?
    @State private var didLoad = false
    @State private var errorMessage: String?
    @State private var storeUpdateURL: URL?
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
                    onResetAllData: { self.settings = nil }
                )
            } else {
                OnboardingView(repository: dependencies.userSettingsRepository) { saved in
                    settings = saved
                }
            }
        }
        .task { await loadSettings() }
        .task { await checkVersion() }
        .sheet(isPresented: $showingWhatsNew) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 18) {
                    Text("ねむちゃーとがアップデートされました 🐑")
                        .font(.title2.bold())
                    Label("睡眠スコアを新しい配点にしました", systemImage: "chart.bar")
                    Label("記録と羊の成長を振り返りやすくしました", systemImage: "sparkles")
                    Label("入力と目標設定を簡単にしました", systemImage: "square.and.pencil")
                    Spacer()
                    Button("はじめる") { showingWhatsNew = false }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                }
                .padding()
                .navigationTitle("今回の変更")
            }
            .presentationDetents([.medium])
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
            Text("新機能や改善を利用するには最新版へのアップデートをおすすめします。")
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

    private func checkVersion() async {
        guard ProcessInfo.processInfo.environment["NEMUCHART_UI_TESTING"] != "1",
              let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        let defaults = UserDefaults.standard
        let key = "NemuChart.lastLaunchedVersion"
        if let previous = defaults.string(forKey: key), previous != current {
            showingWhatsNew = true
        }
        defaults.set(current, forKey: key)
        guard let bundle = Bundle.main.bundleIdentifier,
              var components = URLComponents(string: "https://itunes.apple.com/lookup") else { return }
        components.queryItems = [URLQueryItem(name: "bundleId", value: bundle), URLQueryItem(name: "country", value: "jp")]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(StoreLookup.self, from: data),
              let listing = response.results.first,
              listing.version.compare(current, options: .numeric) == .orderedDescending,
              let storeURL = URL(string: listing.trackViewUrl) else { return }
        storeUpdateURL = storeURL
    }
}

private struct StoreLookup: Decodable {
    struct Listing: Decodable { let version: String; let trackViewUrl: String }
    let results: [Listing]
}
