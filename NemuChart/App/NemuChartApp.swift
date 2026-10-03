import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct NemuChartApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appOrientationDelegate
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

final class AppOrientationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == LocalNotificationService.recordActionIdentifier ||
            response.notification.request.identifier == LocalNotificationService.morningIdentifier {
            await MainActor.run {
                UserDefaults.standard.set(true, forKey: "NemuChart.pendingMorningRecord")
                NotificationCenter.default.post(name: .openMorningRecord, object: nil)
            }
        }
    }
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

extension Notification.Name {
    static let openMorningRecord = Notification.Name("NemuChart.openMorningRecord")
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
