import Foundation

struct WeeklyGoalProgressService: Sendable {
    func weekStart(containing date: Date, settings: UserSettings, timeZone: TimeZone = .current) throws -> SleepDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = settings.weekStart.rawValue
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: date)!
        return try DateTimeService().sleepDay(for: start, timeZoneIdentifier: timeZone.identifier)
    }

    func progress(
        kind: WeeklyGoalKind,
        targetCount: Int,
        weekStart: SleepDay,
        records: [SleepRecord],
        settings: UserSettings,
        latestGoal: SleepGoal?
    ) throws -> WeeklyGoal {
        let keys = dayKeys(start: weekStart, count: 7)
        let weekRecords = Dictionary(grouping: records.filter { keys.contains($0.sleepDay.key) }, by: { $0.sleepDay.key })
            .compactMap { $0.value.max(by: { $0.updatedAt < $1.updatedAt }) }
        let completed = weekRecords.filter { record in
            switch kind {
            case .recordSleep: return true
            case .meetWakeTime:
                return circularDifference(minutes(record.wakeTime, timeZone: weekStart.timeZoneIdentifier), settings.standardWakeTime.minutesSinceMidnight) <= 30
            case .meetSleepDuration:
                return abs(record.sleepDuration - settings.desiredSleepDuration) <= 30 * 60
            case .endSmartphone:
                return record.factors.smartphoneEndTime.map { $0 <= record.bedTime } ?? false
            case .meetBedtime:
                guard let latestGoal else { return false }
                return circularDifference(minutes(record.bedTime, timeZone: weekStart.timeZoneIdentifier), latestGoal.targetBedTime.minutesSinceMidnight) <= 30
            }
        }.count
        return try WeeklyGoal(kind: kind, weekStart: weekStart, targetCount: targetCount, completedCount: min(completed, targetCount))
    }

    func remainingDays(weekStart: SleepDay, now: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: weekStart.timeZoneIdentifier) ?? .current
        let start = calendar.date(from: DateComponents(year: weekStart.year, month: weekStart.month, day: weekStart.day))!
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: end).day ?? 0)
    }

    private func dayKeys(start: SleepDay, count: Int) -> Set<String> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: start.timeZoneIdentifier)!
        let date = calendar.date(from: DateComponents(year: start.year, month: start.month, day: start.day))!
        return Set((0..<count).map { offset in
            let value = calendar.date(byAdding: .day, value: offset, to: date)!
            let c = calendar.dateComponents([.year, .month, .day], from: value)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        })
    }

    private func minutes(_ date: Date, timeZone: String) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
    private func circularDifference(_ lhs: Int, _ rhs: Int) -> Int {
        let direct = abs(lhs - rhs)
        return min(direct, 24 * 60 - direct)
    }
}
