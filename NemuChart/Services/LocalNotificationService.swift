import Foundation
import UserNotifications

@MainActor
protocol LocalNotificationServiceProtocol: AnyObject {
    func authorizationState() async -> NotificationAuthorizationState
    func requestAuthorization() async throws -> NotificationAuthorizationState
    func scheduleWindDown(before targetBedTime: LocalTime) async throws
    func cancelWindDown()
}

@MainActor
final class LocalNotificationService: LocalNotificationServiceProtocol {
    static let windDownIdentifier = "NemuChart.windDown"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func authorizationState() async -> NotificationAuthorizationState {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized: return .authorized
        case .provisional, .ephemeral: return .provisional
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async throws -> NotificationAuthorizationState {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return await authorizationState()
    }

    func scheduleWindDown(before targetBedTime: LocalTime) async throws {
        cancelWindDown()
        let minutes = WindDownNotificationPlanner().notificationMinutes(before: targetBedTime)
        let content = UNMutableNotificationContent()
        content.title = String(localized: "そろそろ休む準備を")
        content.body = String(localized: "アプリを開かなくても大丈夫です。端末を置いて、穏やかに過ごしましょう。")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
            repeats: true
        )
        try await center.add(UNNotificationRequest(
            identifier: Self.windDownIdentifier,
            content: content,
            trigger: trigger
        ))
    }

    func cancelWindDown() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.windDownIdentifier])
    }
}

struct WindDownNotificationPlanner: Sendable {
    func notificationMinutes(before targetBedTime: LocalTime, leadMinutes: Int = 30) -> Int {
        (targetBedTime.minutesSinceMidnight - leadMinutes + 24 * 60) % (24 * 60)
    }
}
