import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencies
    @State private var settings: UserSettings?
    @State private var didLoad = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !didLoad {
                VStack(spacing: 20) {
                    Image(uiImage: UIImage(named: "NemuChartLogoCropped.jpeg") ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 330)
                        .accessibilityLabel("NemuChart")
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
}
