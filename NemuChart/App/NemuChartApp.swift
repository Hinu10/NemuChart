import SwiftUI
import SwiftData

@main
struct NemuChartApp: App {
    private let dependencies: AppDependencies?
    private let startupErrorMessage: String?

    init() {
        do {
            if ProcessInfo.processInfo.environment["NEMUCHART_UI_TESTING"] == "1" {
                dependencies = AppDependencies(modelContainer: try ModelContainerFactory.make(inMemory: true))
            } else {
                dependencies = try AppDependencies.live()
            }
            startupErrorMessage = nil
        } catch {
            dependencies = nil
            startupErrorMessage = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies {
                AppRootView(dependencies: dependencies)
            } else {
                StartupFailureView(message: startupErrorMessage ?? "不明なエラー")
            }
        }
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("データを準備できませんでした")
                .font(.title2.bold())
            Text("端末の空き容量を確認し、アプリを再起動してください。繰り返し表示される場合は、サポートへこの内容を共有してください。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
    }
}
