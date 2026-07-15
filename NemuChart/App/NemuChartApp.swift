import SwiftUI
import SwiftData

@main
struct NemuChartApp: App {
    private let dependencies: AppDependencies

    init() {
        do {
            dependencies = try AppDependencies.live()
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
