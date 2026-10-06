import Foundation
import SwiftUI
import ActivityKit
import AlarmKit
import AppIntents

@available(iOS 26.0, *)
struct NemuAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
struct NemuWakeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "起きた！"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "alarmID") var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    func perform() async throws -> some IntentResult {
        let now = Date()
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
            await NemuAlarmService.recordStop(id: id, at: now)
        }
        UserDefaults.standard.set(now, forKey: "NemuChart.alarmWakeTime")
        await MainActor.run { NotificationCenter.default.post(name: .openMorningRecord, object: nil) }
        return .result()
    }
}

@available(iOS 26.0, *)
struct NemuSnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "スヌーズ"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "alarmID") var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        try AlarmManager.shared.countdown(id: id)
        await NemuAlarmService.recordSnooze(id: id)
        return .result()
    }
}

enum NemuAlarmError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            String(localized: "アラームが許可されていないため設定できませんでした。設定アプリの「ねむちゃーと」でアラームを許可してください。")
        }
    }
}

@MainActor
enum NemuAlarmService {
    private static let idKey = "NemuChart.alarmID"
    static let snoozeMinutes = 9

    /// 予約したアラームと実際に鳴らす音を返す。音源を用意できなければ標準音で予約する。
    @available(iOS 26.0, *)
    @discardableResult
    static func schedule(
        wakeTime: LocalTime,
        sound: AlarmSoundChoice,
        preferences: AppPreferencesStore? = nil
    ) async throws -> AlarmResult {
        let preferences = preferences ?? AppPreferencesStore()
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else { throw NemuAlarmError.notAuthorized }
        cancel(preferences: preferences)
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
        let (alertSound, usedSound) = alertSound(for: sound)
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: .init(preAlert: nil, postAlert: TimeInterval(snoozeMinutes * 60)),
            schedule: .fixed(next), attributes: attributes,
            stopIntent: NemuWakeIntent(alarmID: id),
            secondaryIntent: NemuSnoozeIntent(alarmID: id),
            sound: alertSound
        )
        _ = try await manager.schedule(id: id, configuration: config)
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
        let result = AlarmResult(id: id, scheduledAt: next, sound: usedSound, deliveryMode: .alarmKit)
        update(preferences) { AlarmResultLog.scheduled(result, in: $0) }
        return result
    }

    static func cancel(preferences: AppPreferencesStore? = nil) {
        guard #available(iOS 26.0, *),
              let id = UserDefaults.standard.string(forKey: idKey).flatMap(UUID.init(uuidString:)) else { return }
        try? AlarmManager.shared.cancel(id: id)
        UserDefaults.standard.removeObject(forKey: idKey)
        update(preferences ?? AppPreferencesStore()) { AlarmResultLog.cancelled(id: id, now: Date(), in: $0) }
    }

    static var isAuthorizationDenied: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return AlarmManager.shared.authorizationState == .denied
    }

    static func recordStop(id: UUID, at date: Date) {
        update(AppPreferencesStore()) { AlarmResultLog.stopped(id: id, at: date, in: $0) }
    }

    static func recordSnooze(id: UUID) {
        update(AppPreferencesStore()) { AlarmResultLog.snoozed(id: id, in: $0) }
    }

    private static func update(_ preferences: AppPreferencesStore, _ transform: ([AlarmResult]) -> [AlarmResult]) {
        var data = preferences.load()
        data.alarmResults = transform(data.alarmResults)
        try? preferences.save(data)
    }

    @available(iOS 26.0, *)
    private static func alertSound(for sound: AlarmSoundChoice) -> (AlertConfiguration.AlertSound, AlarmSoundChoice) {
        guard sound != .system else { return (.default, .system) }
        do {
            let directory = try FileManager.default
                .url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Sounds", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = "nemuchart-\(sound.rawValue).wav"
            let url = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                try AlarmSoundSynthesizer.alarmWAV(sound).write(to: url, options: .atomic)
            }
            return (.named(name), sound)
        } catch {
            return (.default, .system)
        }
    }
}
