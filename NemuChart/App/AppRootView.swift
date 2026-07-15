import SwiftUI

struct AppRootView: View {
    let dependencies: AppDependencies
    @State private var settings: UserSettings?
    @State private var didLoad = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !didLoad {
                ProgressView("設定を読み込んでいます")
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
        .task { loadSettings() }
        .alert("読み込みエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("再試行") { loadSettings() }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadSettings() {
        do {
            settings = try dependencies.userSettingsRepository.load()
            didLoad = true
        } catch {
            errorMessage = error.localizedDescription
            didLoad = true
        }
    }
}
