import Foundation

struct GoalPlanningService: Sendable {
    static let minimumLatencySamples = 3
    static let maximumAdoptedLatencyMinutes = 120

    func plan(settings: UserSettings, records: [SleepRecord]) -> GoalPlan {
        let observed = records.map { Int($0.sleepStart.timeIntervalSince($0.bedTime) / 60) }
            .filter { (0...Self.maximumAdoptedLatencyMinutes).contains($0) }
        let useObserved = observed.count >= Self.minimumLatencySamples
        let latency = useObserved
            ? Int((Double(observed.reduce(0, +)) / Double(observed.count)).rounded())
            : settings.averageSleepLatencyMinutes ?? 20
        let wake = settings.standardWakeTime.minutesSinceMidnight
        let sleep = normalized(wake - Int(settings.desiredSleepDuration / 60))
        let bed = normalized(sleep - latency)
        return GoalPlan(
            targetBedTime: localTime(bed),
            targetSleepTime: localTime(sleep),
            targetWakeTime: settings.standardWakeTime,
            sleepLatencyMinutes: latency,
            usedObservedLatency: useObserved
        )
    }

    private func normalized(_ minutes: Int) -> Int { (minutes % (24 * 60) + 24 * 60) % (24 * 60) }
    private func localTime(_ minutes: Int) -> LocalTime { LocalTime(hour: minutes / 60, minute: minutes % 60)! }
}
