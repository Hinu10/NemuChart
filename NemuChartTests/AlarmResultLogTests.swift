import XCTest
@testable import NemuChart

final class AlarmResultLogTests: XCTestCase {
    private let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)

    func testSnoozeAndStopUpdateOnlyMatchingAlarm() {
        let target = AlarmResult(scheduledAt: scheduledAt, sound: .birds, deliveryMode: .alarmKit)
        let other = AlarmResult(scheduledAt: scheduledAt, sound: .system, deliveryMode: .alarmKit)
        var results = [target, other]
        results = AlarmResultLog.snoozed(id: target.id, in: results)
        results = AlarmResultLog.snoozed(id: target.id, in: results)
        results = AlarmResultLog.stopped(id: target.id, at: scheduledAt.addingTimeInterval(18 * 60), in: results)
        results = AlarmResultLog.snoozed(id: target.id, in: results)

        XCTAssertEqual(results[0].snoozeCount, 2)
        XCTAssertEqual(results[0].stoppedAt, scheduledAt.addingTimeInterval(18 * 60))
        XCTAssertEqual(results[1], other)
    }

    func testCancelRemovesOnlyUnfiredFutureAlarm() {
        let future = AlarmResult(scheduledAt: scheduledAt, sound: .system, deliveryMode: .alarmKit)
        let fired = AlarmResult(scheduledAt: scheduledAt, sound: .system, snoozeCount: 1, deliveryMode: .alarmKit)
        let before = scheduledAt.addingTimeInterval(-60)
        XCTAssertTrue(AlarmResultLog.cancelled(id: future.id, now: before, in: [future]).isEmpty)
        XCTAssertEqual(AlarmResultLog.cancelled(id: fired.id, now: before, in: [fired]), [fired])
        XCTAssertEqual(AlarmResultLog.cancelled(id: future.id, now: scheduledAt.addingTimeInterval(60), in: [future]), [future])
    }

    func testScheduledKeepsBoundedHistory() {
        var results: [AlarmResult] = []
        for _ in 0..<(AlarmResultLog.maximumCount + 5) {
            results = AlarmResultLog.scheduled(
                AlarmResult(scheduledAt: scheduledAt, sound: .system, deliveryMode: .alarmKit), in: results
            )
        }
        XCTAssertEqual(results.count, AlarmResultLog.maximumCount)
    }

    func testSummariesIgnoreUnstoppedAlarms() throws {
        let results = [
            AlarmResult(scheduledAt: scheduledAt, sound: .gentleChime, snoozeCount: 1,
                        stoppedAt: scheduledAt.addingTimeInterval(10 * 60), deliveryMode: .alarmKit),
            AlarmResult(scheduledAt: scheduledAt, sound: .gentleChime, snoozeCount: 0,
                        stoppedAt: scheduledAt.addingTimeInterval(2 * 60), deliveryMode: .alarmKit),
            AlarmResult(scheduledAt: scheduledAt, sound: .birds, deliveryMode: .alarmKit)
        ]
        let summaries = AlarmResultLog.summaries(results)
        XCTAssertEqual(summaries.map(\.sound), [.gentleChime])
        let chime = try XCTUnwrap(summaries.first)
        XCTAssertEqual(chime.stoppedCount, 2)
        XCTAssertEqual(chime.averageSnoozeCount, 0.5, accuracy: 0.001)
        XCTAssertEqual(chime.averageMinutesToStop, 6, accuracy: 0.001)
    }

    func testAlarmWAVHasValidHeader() {
        let data = AlarmSoundSynthesizer.alarmWAV(.gentleChime, totalDuration: 1)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(data.count, 44 + Int(AlarmSoundSynthesizer.sampleRate) * 2)
    }

    func testEverySoundHasAudiblePhrase() {
        for sound in AlarmSoundChoice.allCases {
            let phrase = AlarmSoundSynthesizer.phrase(sound)
            XCTAssertEqual(phrase.count, Int(AlarmSoundSynthesizer.sampleRate * AlarmSoundSynthesizer.phraseDuration(sound)))
            XCTAssertGreaterThan(phrase.map(abs).max() ?? 0, 0.05, "\(sound)")
            XCTAssertLessThanOrEqual(phrase.map(abs).max() ?? 0, 0.25, "\(sound)")
        }
    }

    func testVoiceSoundsHaveSpeechAndOthersDoNot() {
        XCTAssertEqual(AlarmSoundChoice.voiceMorning.speechText, "朝です。起きなさい！")
        XCTAssertNotNil(AlarmSoundChoice.voiceCountdown.speechText)
        XCTAssertNil(AlarmSoundChoice.siren.speechText)
    }

    func testResampleConvertsRate() {
        let source = [Float](repeating: 0.5, count: 22_050)
        let resampled = AlarmSoundSynthesizer.resample(source, from: 22_050)
        XCTAssertEqual(resampled.count, 44_100)
        XCTAssertEqual(resampled[1_000], 0.5, accuracy: 0.0001)
    }

    func testAlarmWAVIncludesSpeechSamples() {
        let speech = [Float](repeating: 0.1, count: 1_000)
        let data = AlarmSoundSynthesizer.alarmWAV(.voiceMorning, speech: speech, totalDuration: 1)
        XCTAssertEqual(data.count, 44 + Int(AlarmSoundSynthesizer.sampleRate) * 2)
    }
}
