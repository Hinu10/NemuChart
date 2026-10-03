import Foundation

struct SheepCollectible: Identifiable, Sendable {
    enum Category: String, CaseIterable, Sendable { case accessory = "小物", background = "背景", effect = "特別演出" }
    let id: String
    let name: String
    let symbol: String
    let category: Category
    let requiredGrowth: Int

    static let all: [Self] = [
        .init(id: "nightcap", name: "ナイトキャップ", symbol: "moon.stars.fill", category: .accessory, requiredGrowth: 50),
        .init(id: "sparkle", name: "きらきら", symbol: "sparkles", category: .effect, requiredGrowth: 100),
        .init(id: "morning", name: "朝の草原", symbol: "sunrise.fill", category: .background, requiredGrowth: 180),
        .init(id: "scarf", name: "マフラー", symbol: "wind", category: .accessory, requiredGrowth: 300),
        .init(id: "stars", name: "星空の丘", symbol: "star.circle.fill", category: .background, requiredGrowth: 450),
        .init(id: "flowers", name: "花の舞", symbol: "camera.macro", category: .effect, requiredGrowth: 650),
        .init(id: "ribbon", name: "リボン", symbol: "ribbon", category: .accessory, requiredGrowth: 900),
        .init(id: "sunset", name: "夕焼けの丘", symbol: "sunset.fill", category: .background, requiredGrowth: 1200),
        .init(id: "moonlight", name: "月あかり", symbol: "moon.circle.fill", category: .effect, requiredGrowth: 1600),
        .init(id: "garden", name: "ひつじの庭", symbol: "leaf.fill", category: .background, requiredGrowth: 2100)
    ]
}

struct SheepVitalityService: Sendable {
    func vitality(scores: [DailySleepScore]) -> Vitality {
        guard let latest = scores.first?.total else { return .calm }
        switch latest {
        case 90...100: return .radiant
        case 75..<90: return .lively
        case 60..<75: return .calm
        case 40..<60: return .resting
        default: return .drowsy
        }
    }
}

struct SheepGrowthService: Sendable {
    static let pointsPerRecord = 10
    static let pointsPerAction = 2
    static let pointsPerWeeklyGoal = 5

    struct Earning: Codable, Equatable, Sendable {
        let recordID: UUID
        let recordPoints: Int
        let scorePoints: Int
        let streakPoints: Int
        let tonightPoints: Int
        var total: Int { recordPoints + scorePoints + streakPoints + tonightPoints }
    }

    func earnings(records: [SleepRecord], scores: [DailySleepScore], goals: [SleepGoal] = []) -> [Earning] {
        let scoreByDay = Dictionary(grouping: scores, by: { $0.sleepDay.key }).mapValues { $0.last?.total ?? 0 }
        let ordered = Dictionary(grouping: records, by: { $0.sleepDay.key })
            .compactMap { $0.value.max(by: { $0.updatedAt < $1.updatedAt }) }
            .sorted { $0.sleepDay < $1.sleepDay }
        var previous: Date?
        var streak = 0
        return ordered.map { record in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: record.sleepDay.timeZoneIdentifier) ?? .current
            let day = calendar.date(from: DateComponents(year: record.sleepDay.year, month: record.sleepDay.month, day: record.sleepDay.day))!
            streak = previous.map { calendar.dateComponents([.day], from: $0, to: day).day == 1 } == true ? streak + 1 : 1
            previous = day
            let streakPoints = streak >= 14 ? 3 : streak >= 7 ? 2 : streak >= 3 ? 1 : 0
            let tonightPoints = goals.contains { goal in
                let gap = abs(record.bedTime.timeIntervalSince(goal.createdAt))
                guard gap < 36 * 3600, !record.isAllNighter else { return false }
                let wake = calendar.component(.hour, from: record.wakeTime) * 60 + calendar.component(.minute, from: record.wakeTime)
                let sleep = calendar.component(.hour, from: record.sleepStart) * 60 + calendar.component(.minute, from: record.sleepStart)
                let bed = calendar.component(.hour, from: record.bedTime) * 60 + calendar.component(.minute, from: record.bedTime)
                func difference(_ lhs: Int, _ rhs: Int) -> Int {
                    let value = abs(lhs - rhs)
                    return min(value, 1440 - value)
                }
                return difference(wake, goal.targetWakeTime.minutesSinceMidnight) <= 15
                    && difference(sleep, goal.targetSleepTime.minutesSinceMidnight) <= 30
                    && difference(bed, goal.targetBedTime.minutesSinceMidnight) <= 30
            } ? 2 : 0
            return Earning(recordID: record.id, recordPoints: 10,
                           scorePoints: Int((Double(scoreByDay[record.sleepDay.key] ?? 0) / 10).rounded()),
                           streakPoints: streakPoints, tonightPoints: tonightPoints)
        }
    }

    func summary(earnings: [Earning], completedWeeklyGoalIDs: [UUID] = []) -> SheepGrowthSummary {
        let total = earnings.reduce(0) { $0 + $1.total } + Set(completedWeeklyGoalIDs).count * Self.pointsPerWeeklyGoal
        return summary(total: total)
    }

    private func summary(total: Int) -> SheepGrowthSummary {
        let stage: GrowthStage
        let next: Int?
        switch total {
        case 0..<50: stage = .lamb; next = 50 - total
        case 50..<150: stage = .young; next = 150 - total
        default: stage = .grown; next = nil
        }
        return SheepGrowthSummary(points: GrowthPoints(total), stage: stage, pointsToNextStage: next)
    }

    func summary(
        recordIDs: [UUID],
        completedActionIDs: [UUID] = [],
        completedWeeklyGoalIDs: [UUID] = []
    ) -> SheepGrowthSummary {
        let total = Set(recordIDs).count * Self.pointsPerRecord
            + Set(completedActionIDs).count * Self.pointsPerAction
            + Set(completedWeeklyGoalIDs).count * Self.pointsPerWeeklyGoal
        return summary(total: total)
    }
}

struct LandscapeStateService: Sendable {
    func state(timeOfDay: HomeTimeOfDay, vitality: Vitality) -> LandscapeState {
        let mood: LandscapeMood
        switch vitality {
        case .radiant, .lively: mood = .clear
        case .calm: mood = .gentle
        case .resting, .drowsy: mood = .cloudy
        }
        return LandscapeState(timeOfDay: timeOfDay, mood: mood)
    }
}
