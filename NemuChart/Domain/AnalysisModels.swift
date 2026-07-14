import Foundation

struct ScoreComponent: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case duration
        case timing
        case freshness
        case continuity
    }

    let kind: Kind
    let points: Int
    let possiblePoints: Int

    init(kind: Kind, points: Int, possiblePoints: Int) throws {
        guard possiblePoints > 0, (0...possiblePoints).contains(points) else {
            throw ScoreValidationError.invalidComponent
        }
        self.kind = kind
        self.points = points
        self.possiblePoints = possiblePoints
    }
}

struct DailySleepScore: Codable, Equatable, Sendable {
    let sleepDay: SleepDay
    let total: Int
    let components: [ScoreComponent]
    let ruleVersion: String

    init(
        sleepDay: SleepDay,
        total: Int,
        components: [ScoreComponent],
        ruleVersion: String
    ) throws {
        guard (0...100).contains(total) else { throw ScoreValidationError.invalidTotal }
        guard !ruleVersion.isEmpty else { throw ScoreValidationError.missingRuleVersion }
        self.sleepDay = sleepDay
        self.total = total
        self.components = components
        self.ruleVersion = ruleVersion
    }
}

enum GoalAchievement: Codable, Equatable, Sendable {
    case unavailable(reason: String)
    case measured(progress: Double)

    var progress: Double? {
        guard case .measured(let progress) = self else { return nil }
        return progress
    }

    static func measuredClamped(_ progress: Double) -> GoalAchievement {
        .measured(progress: min(max(progress, 0), 1))
    }
}

enum AnalysisConfidence: String, Codable, CaseIterable, Sendable {
    case insufficient
    case low
    case moderate
    case high
}

struct WeeklySleepReport: Codable, Equatable, Sendable {
    let startDay: SleepDay
    let endDay: SleepDay
    let recordedDayCount: Int
    let score: Int?
    let confidence: AnalysisConfidence

    init(
        startDay: SleepDay,
        endDay: SleepDay,
        recordedDayCount: Int,
        score: Int?,
        confidence: AnalysisConfidence
    ) throws {
        guard startDay <= endDay, (0...7).contains(recordedDayCount) else {
            throw ScoreValidationError.invalidWeeklyReport
        }
        guard score.map({ (0...100).contains($0) }) ?? true else {
            throw ScoreValidationError.invalidTotal
        }
        guard recordedDayCount > 0 || score == nil else {
            throw ScoreValidationError.invalidWeeklyReport
        }
        self.startDay = startDay
        self.endDay = endDay
        self.recordedDayCount = recordedDayCount
        self.score = score
        self.confidence = confidence
    }
}

enum ScoreValidationError: Error, Equatable {
    case invalidTotal
    case invalidComponent
    case missingRuleVersion
    case invalidWeeklyReport
}

