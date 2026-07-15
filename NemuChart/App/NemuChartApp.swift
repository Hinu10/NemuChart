import SwiftUI
import SwiftData

@main
struct NemuChartApp: App {
    private let dependencies: AppDependencies

    init() {
        do {
            if ProcessInfo.processInfo.environment["NEMUCHART_UI_TESTING"] == "1" {
                dependencies = AppDependencies(modelContainer: try ModelContainerFactory.make(inMemory: true))
            } else {
                dependencies = try AppDependencies.live()
            }
        } catch {
            fatalError("ModelContainerの初期化に失敗しました: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
        .modelContainer(dependencies.modelContainer)
    }
}
