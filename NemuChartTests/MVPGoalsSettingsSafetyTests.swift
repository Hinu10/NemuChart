import XCTest
@testable import NemuChart

@MainActor
final class MVPGoalsSettingsSafetyTests: XCTestCase {
    func testGoalPlanCrossesMidnightUsingFallbackLatency() throws {
        let settings = try UserSettings(
            desiredSleepDuration: 8 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!,
            averageSleepLatencyMinutes: 30
        )
        let plan = GoalPlanningService().plan(settings: settings, records: [])

        XCTAssertEqual(plan.targetWakeTime, LocalTime(hour: 7, minute: 0)!)
        XCTAssertEqual(plan.targetSleepTime, LocalTime(hour: 23, minute: 0)!)
        XCTAssertEqual(plan.targetBedTime, LocalTime(hour: 22, minute: 30)!)
        XCTAssertFalse(plan.usedObservedLatency)
    }

    func testGoalPlanAdoptsObservedLatencyOnlyAfterThreeValidSamples() throws {
        let settings = try UserSettings(
            desiredSleepDuration: 8 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!,
            averageSleepLatencyMinutes: 20
        )
        let records = try [10, 20, 30].enumerated().map { index, latency in
            try record(day: 10 + index, latencyMinutes: latency)
        }
        let two = GoalPlanningService().plan(settings: settings, records: Array(records.prefix(2)))
        let three = GoalPlanningService().plan(settings: settings, records: records)

        XCTAssertEqual(two.sleepLatencyMinutes, 20)
        XCTAssertFalse(two.usedObservedLatency)
        XCTAssertEqual(three.sleepLatencyMinutes, 20)
        XCTAssertTrue(three.usedObservedLatency)
    }

    func testWeeklyGoalUsesConfiguredWeekStartAndCountsOnlyRecordedDays() throws {
        let settings = try UserSettings(
            desiredSleepDuration: 7.5 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!,
            weekStart: .monday
        )
        let service = WeeklyGoalProgressService()
        let now = TestFixtures.date(2026, 7, 15, 12, 0)
        let start = try service.weekStart(containing: now, settings: settings, timeZone: TestFixtures.tokyo)
        let records = try [14, 15].map { try TestFixtures.sleepRecord(day: $0) }
        let goal = try service.progress(
            kind: .recordSleep, targetCount: 3, weekStart: start,
            records: records, settings: settings, latestGoal: nil
        )

        XCTAssertEqual(start.key, "2026-07-13")
        XCTAssertEqual(goal.completedCount, 2)
        XCTAssertEqual(goal.progress, 2.0 / 3.0, accuracy: 0.001)
    }

    func testWeeklyGoalRewardIDsRemainUniqueAfterPersistence() throws {
        let suiteName = "NemuChartTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppPreferencesStore(defaults: defaults)
        let id = UUID()
        var data = store.load()
        data.rewardedWeeklyGoalIDs.insert(id)
        data.rewardedWeeklyGoalIDs.insert(id)
        try store.save(data)

        XCTAssertEqual(store.load().rewardedWeeklyGoalIDs, Set([id]))
    }

    func testWindDownNotificationWrapsToPreviousDay() {
        let planner = WindDownNotificationPlanner()
        XCTAssertEqual(planner.notificationMinutes(before: LocalTime(hour: 0, minute: 15)!), 23 * 60 + 45)
        XCTAssertEqual(planner.notificationMinutes(before: LocalTime(hour: 23, minute: 0)!), 22 * 60 + 30)
    }

    func testSafetyGuidanceRequiresThreeRecordsAndHonorsCooldown() throws {
        let service = SafetyGuidanceService()
        let two = try [13, 14].map { try TestFixtures.sleepRecord(day: $0, freshness: .veryTired) }
        let three = try [12, 13, 14].map { try TestFixtures.sleepRecord(day: $0, freshness: .veryTired) }
        let now = TestFixtures.date(2026, 7, 15, 12, 0)

        XCTAssertNil(service.guidance(records: two, dismissedAt: nil, now: now))
        let guidance = try XCTUnwrap(service.guidance(records: three, dismissedAt: nil, now: now))
        XCTAssertFalse(guidance.message.contains("病名"))
        XCTAssertFalse(guidance.message.contains("診断"))
        XCTAssertFalse(guidance.message.contains("緊急"))
        XCTAssertNil(service.guidance(records: three, dismissedAt: now.addingTimeInterval(-13 * 24 * 3600), now: now))
        XCTAssertNotNil(service.guidance(records: three, dismissedAt: now.addingTimeInterval(-15 * 24 * 3600), now: now))
    }

    private func record(day: Int, latencyMinutes: Int) throws -> SleepRecord {
        let sleepDay = try SleepDay(year: 2026, month: 7, day: day, timeZoneIdentifier: "Asia/Tokyo")
        let bed = TestFixtures.date(2026, 7, day - 1, 23, 0)
        return try SleepRecord(
            sleepDay: sleepDay,
            bedTime: bed,
            sleepStart: bed.addingTimeInterval(TimeInterval(latencyMinutes * 60)),
            wakeTime: TestFixtures.date(2026, 7, day, 7, 0),
            freshness: .neutral
        )
    }
}
