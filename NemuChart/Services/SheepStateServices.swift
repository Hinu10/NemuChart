import Foundation

struct SheepVitalityService: Sendable {
    func vitality(scores: [DailySleepScore]) -> Vitality {
        let latest = Array(scores.prefix(5)).map(\.total)
        guard !latest.isEmpty else { return .calm }
        if latest.count >= 2, latest.prefix(2).allSatisfy({ $0 >= 80 }) { return .radiant }
        if latest[0] >= 70 { return .lively }
        guard latest.count >= 3 else { return .calm }
        let recentAverage = Double(latest.prefix(3).reduce(0, +)) / Double(min(3, latest.count))
        return recentAverage < 50 ? .resting : .calm
    }
}

struct SheepGrowthService: Sendable {
    static let pointsPerRecord = 10
    static let pointsPerAction = 5
    static let pointsPerWeeklyGoal = 15

    func summary(
        recordIDs: [UUID],
        completedActionIDs: [UUID] = [],
        completedWeeklyGoalIDs: [UUID] = []
    ) -> SheepGrowthSummary {
        let total = Set(recordIDs).count * Self.pointsPerRecord
            + Set(completedActionIDs).count * Self.pointsPerAction
            + Set(completedWeeklyGoalIDs).count * Self.pointsPerWeeklyGoal
        let stage: GrowthStage
        let next: Int?
        switch total {
        case 0..<50: stage = .lamb; next = 50 - total
        case 50..<150: stage = .young; next = 150 - total
        default: stage = .grown; next = nil
        }
        return SheepGrowthSummary(points: GrowthPoints(total), stage: stage, pointsToNextStage: next)
    }
}

struct LandscapeStateService: Sendable {
    func state(timeOfDay: HomeTimeOfDay, vitality: Vitality) -> LandscapeState {
        let mood: LandscapeMood
        switch vitality {
        case .radiant, .lively: mood = .clear
        case .calm: mood = .gentle
        case .resting: mood = .cloudy
        }
        return LandscapeState(timeOfDay: timeOfDay, mood: mood)
    }
}
