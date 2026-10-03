import Foundation
import SwiftUI
import AlarmKit
import AppIntents

@available(iOS 26.0, *)
struct NemuAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
struct NemuWakeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "起きた！"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(Date(), forKey: "NemuChart.alarmWakeTime")
        await MainActor.run { NotificationCenter.default.post(name: .openMorningRecord, object: nil) }
        return .result()
    }
}

@MainActor
enum NemuAlarmService {
    private static let idKey = "NemuChart.alarmID"

    @available(iOS 26.0, *)
    static func schedule(wakeTime: LocalTime) async throws {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else { return }
        cancel()
        var calendar = Calendar.current
        calendar.timeZone = .current
        let now = Date()
        let next = calendar.nextDate(after: now, matching: DateComponents(hour: wakeTime.hour, minute: wakeTime.minute), matchingPolicy: .nextTime)!
        let id = UUID()
        let stop = AlarmButton(text: "起きた！", textColor: .white, systemImageName: "sun.max.fill")
        let snooze = AlarmButton(text: "スヌーズ", textColor: .white, systemImageName: "zzz")
        let alert = AlarmPresentation.Alert(title: "ねむちゃーと", stopButton: stop,
                                            secondaryButton: snooze, secondaryButtonBehavior: .countdown)
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<NemuAlarmMetadata>(presentation: presentation, tintColor: .indigo)
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: .init(preAlert: nil, postAlert: 9 * 60),
            schedule: .fixed(next), attributes: attributes,
            stopIntent: NemuWakeIntent(), sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: config)
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
    }

    static func cancel() {
        guard #available(iOS 26.0, *),
              let id = UserDefaults.standard.string(forKey: idKey).flatMap(UUID.init(uuidString:)) else { return }
        try? AlarmManager.shared.cancel(id: id)
        UserDefaults.standard.removeObject(forKey: idKey)
    }
}
