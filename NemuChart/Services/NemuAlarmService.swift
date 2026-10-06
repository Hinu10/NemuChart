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
        try await NemuAlarmService.snooze(id: id)
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
    /// スヌーズで予約し直しても、結果は最初の予約にまとめて記録する。
    private static let resultIDKey = "NemuChart.alarmResultID"
    private static let snoozeUntilKey = "NemuChart.alarmSnoozeUntil"
    static let snoozeMinutes = 10

    /// セット済みで、まだ止めていないアラーム。スヌーズ中は次に鳴る時刻を返す。
    static func upcoming(in data: AppPreferenceData, now: Date = Date()) -> (date: Date, sound: AlarmSoundChoice, isSnoozed: Bool)? {
        guard UserDefaults.standard.bool(forKey: "NemuChart.alarmEnabled") else { return nil }
        let pending = data.alarmResults.filter { $0.stoppedAt == nil }
        if let snoozedUntil = (UserDefaults.standard.object(forKey: snoozeUntilKey) as? Date), snoozedUntil > now,
           let latest = pending.max(by: { $0.scheduledAt < $1.scheduledAt }) {
            return (snoozedUntil, latest.sound, true)
        }
        return pending
            .filter { $0.scheduledAt > now }
            .min { $0.scheduledAt < $1.scheduledAt }
            .map { ($0.scheduledAt, $0.sound, false) }
    }

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
        let (alertSound, usedSound) = await alertSound(for: sound)
        let config = configuration(id: id, at: next, sound: alertSound)
        _ = try await manager.schedule(id: id, configuration: config)
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
        UserDefaults.standard.set(id.uuidString, forKey: resultIDKey)
        UserDefaults.standard.removeObject(forKey: snoozeUntilKey)
        let result = AlarmResult(id: id, scheduledAt: next, sound: usedSound, deliveryMode: .alarmKit)
        update(preferences) { AlarmResultLog.scheduled(result, in: $0) }
        return result
    }

    static func cancel(preferences: AppPreferencesStore? = nil) {
        guard #available(iOS 26.0, *),
              let id = UserDefaults.standard.string(forKey: idKey).flatMap(UUID.init(uuidString:)) else { return }
        try? AlarmManager.shared.cancel(id: id)
        let resultID = self.resultID(for: id)
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: snoozeUntilKey)
        update(preferences ?? AppPreferencesStore()) { AlarmResultLog.cancelled(id: resultID, now: Date(), in: $0) }
    }

    /// AlarmKit の組み込みカウントダウンは Live Activity のウィジェットがないと動かないため、
    /// 鳴っているアラームを止めて、同じ音で snoozeMinutes 分後に予約し直す。
    @available(iOS 26.0, *)
    static func snooze(id: UUID) async throws {
        let manager = AlarmManager.shared
        try? manager.stop(id: id)
        try? manager.cancel(id: id)
        let resultID = resultID(for: id)
        let data = AppPreferencesStore().load()
        let sound = data.alarmResults.first { $0.id == resultID }?.sound ?? data.alarmSound
        let (alertSound, _) = await alertSound(for: sound)
        let date = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))
        var nextID = id
        do {
            _ = try await manager.schedule(id: nextID, configuration: configuration(id: nextID, at: date, sound: alertSound))
        } catch {
            // 同じIDで予約し直せない場合は新しいIDで予約する。
            nextID = UUID()
            _ = try await manager.schedule(id: nextID, configuration: configuration(id: nextID, at: date, sound: alertSound))
        }
        UserDefaults.standard.set(nextID.uuidString, forKey: idKey)
        UserDefaults.standard.set(resultID.uuidString, forKey: resultIDKey)
        UserDefaults.standard.set(date, forKey: snoozeUntilKey)
        update(AppPreferencesStore()) { AlarmResultLog.snoozed(id: resultID, in: $0) }
    }

    @available(iOS 26.0, *)
    private static func configuration(
        id: UUID,
        at date: Date,
        sound: AlertConfiguration.AlertSound
    ) -> AlarmManager.AlarmConfiguration<NemuAlarmMetadata> {
        let stop = AlarmButton(text: "起きた！", textColor: .white, systemImageName: "sun.max.fill")
        let snooze = AlarmButton(text: "スヌーズ", textColor: .white, systemImageName: "zzz")
        let alert = AlarmPresentation.Alert(title: "ねむちゃーと", stopButton: stop,
                                            secondaryButton: snooze, secondaryButtonBehavior: .custom)
        let attributes = AlarmAttributes<NemuAlarmMetadata>(presentation: AlarmPresentation(alert: alert), tintColor: .indigo)
        return AlarmManager.AlarmConfiguration(
            schedule: .fixed(date), attributes: attributes,
            stopIntent: NemuWakeIntent(alarmID: id),
            secondaryIntent: NemuSnoozeIntent(alarmID: id),
            sound: sound
        )
    }

    private static func resultID(for alarmID: UUID) -> UUID {
        UserDefaults.standard.string(forKey: resultIDKey).flatMap(UUID.init(uuidString:)) ?? alarmID
    }

    static var isAuthorizationDenied: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return AlarmManager.shared.authorizationState == .denied
    }

    static func recordStop(id: UUID, at date: Date) {
        UserDefaults.standard.removeObject(forKey: snoozeUntilKey)
        let resultID = resultID(for: id)
        update(AppPreferencesStore()) { AlarmResultLog.stopped(id: resultID, at: date, in: $0) }
    }

    private static func update(_ preferences: AppPreferencesStore, _ transform: ([AlarmResult]) -> [AlarmResult]) {
        var data = preferences.load()
        data.alarmResults = transform(data.alarmResults)
        try? preferences.save(data)
    }

    @available(iOS 26.0, *)
    private static func alertSound(for sound: AlarmSoundChoice) async -> (AlertConfiguration.AlertSound, AlarmSoundChoice) {
        guard sound != .system else { return (.default, .system) }
        do {
            let directory = try FileManager.default
                .url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Sounds", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = "nemuchart-\(sound.rawValue)-v\(soundFileVersion).wav"
            let url = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                var speech: [Float] = []
                if let text = sound.speechText {
                    speech = try await AlarmSpeechRenderer().render(text)
                }
                try AlarmSoundSynthesizer.alarmWAV(sound, speech: speech).write(to: url, options: .atomic)
            }
            return (.named(name), sound)
        } catch {
            return (.default, .system)
        }
    }

    /// 音の作り方を変えたら上げる。古いファイルを使い回さないため。
    private static let soundFileVersion = 3
}
