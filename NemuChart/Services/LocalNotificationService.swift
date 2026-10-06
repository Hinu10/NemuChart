import Foundation
import UserNotifications

@MainActor
protocol LocalNotificationServiceProtocol: AnyObject {
    func authorizationState() async -> NotificationAuthorizationState
    func requestAuthorization() async throws -> NotificationAuthorizationState
    func scheduleWindDown(before targetBedTime: LocalTime) async throws
    func cancelWindDown()
    func scheduleMorning(at wakeTime: LocalTime) async throws
    func cancelMorning()
}

extension LocalNotificationServiceProtocol {
    func scheduleMorning(at wakeTime: LocalTime) async throws {}
    func cancelMorning() {}
}

@MainActor
final class LocalNotificationService: LocalNotificationServiceProtocol {
    static let windDownIdentifier = "NemuChart.windDown"
    static let morningIdentifier = "NemuChart.morningRecord"
    static let recordActionIdentifier = "NemuChart.recordNow"
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

    func scheduleMorning(at wakeTime: LocalTime) async throws {
        cancelMorning()
        let content = UNMutableNotificationContent()
        content.title = "今朝の睡眠を記録しませんか"
        content.body = "覚えている範囲で大丈夫です。"
        content.sound = .default
        content.categoryIdentifier = "NemuChart.morningCategory"
        let action = UNNotificationAction(identifier: Self.recordActionIdentifier, title: "記録する", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: content.categoryIdentifier, actions: [action], intentIdentifiers: [])])
        try await center.add(UNNotificationRequest(
            identifier: Self.morningIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: wakeTime.hour, minute: wakeTime.minute), repeats: true)
        ))
    }

    func cancelMorning() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningIdentifier])
    }
}

struct WindDownNotificationPlanner: Sendable {
    /// 通常の起床時刻から希望する睡眠時間をさかのぼった就寝時刻。日によって変わらないので、通知が前日の操作に引きずられない。
    func bedTime(wake: LocalTime, sleepDuration: TimeInterval) -> LocalTime {
        let minutes = ((wake.minutesSinceMidnight - Int(sleepDuration / 60)) % (24 * 60) + 24 * 60) % (24 * 60)
        return LocalTime(hour: minutes / 60, minute: minutes % 60)!
    }

    func notificationMinutes(before targetBedTime: LocalTime, leadMinutes: Int = 30) -> Int {
        (targetBedTime.minutesSinceMidnight - leadMinutes + 24 * 60) % (24 * 60)
    }
}
