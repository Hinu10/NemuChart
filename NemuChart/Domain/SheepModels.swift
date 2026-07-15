import Foundation

enum Vitality: String, Codable, CaseIterable, Sendable {
    case resting
    case calm
    case lively
    case radiant
}

enum GrowthStage: Int, Codable, CaseIterable, Sendable {
    case lamb
    case young
    case grown
    case companion
}

struct GrowthPoints: Codable, Equatable, Comparable, Sendable {
    private(set) var value: Int

    init(_ value: Int) {
        self.value = max(0, value)
    }

    mutating func add(_ points: Int) {
        guard points > 0 else { return }
        value += points
    }

    static func < (lhs: GrowthPoints, rhs: GrowthPoints) -> Bool { lhs.value < rhs.value }
}

struct SheepState: Codable, Equatable, Sendable {
    var vitality: Vitality
    var growthStage: GrowthStage
    var growthPoints: GrowthPoints
}

struct SheepGrowthSummary: Equatable, Sendable {
    let points: GrowthPoints
    let stage: GrowthStage
    let pointsToNextStage: Int?
}

enum LandscapeCondition: String, Codable, CaseIterable, Sendable {
    case dawn
    case daytime
    case sunset
    case night
    case restfulNight
}

enum LandscapeMood: String, Codable, CaseIterable, Sendable {
    case clear
    case gentle
    case cloudy
}

struct LandscapeState: Equatable, Sendable {
    let timeOfDay: HomeTimeOfDay
    let mood: LandscapeMood
}

struct SheepFeedback: Equatable, Sendable {
    let status: String
    let positivePoint: String
    let suggestion: String?
    let closing: String

    var combinedMessage: String {
        [status, positivePoint, suggestion, closing].compactMap { $0 }.joined(separator: "\n")
    }
}

enum WeeklyGoalKind: String, Codable, CaseIterable, Sendable {
    case recordSleep
    case meetSleepDuration
    case meetBedtime
}

struct WeeklyGoal: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: WeeklyGoalKind
    let weekStart: SleepDay
    let targetCount: Int
    private(set) var completedCount: Int

    init(
        id: UUID = UUID(),
        kind: WeeklyGoalKind,
        weekStart: SleepDay,
        targetCount: Int,
        completedCount: Int = 0
    ) throws {
        guard (1...7).contains(targetCount), (0...targetCount).contains(completedCount) else {
            throw WeeklyGoalError.invalidProgress
        }
        self.id = id
        self.kind = kind
        self.weekStart = weekStart
        self.targetCount = targetCount
        self.completedCount = completedCount
    }

    var progress: Double { Double(completedCount) / Double(targetCount) }

    mutating func updateCompletedCount(_ count: Int) throws {
        guard (0...targetCount).contains(count) else { throw WeeklyGoalError.invalidProgress }
        completedCount = count
    }
}

enum WeeklyGoalError: Error, Equatable {
    case invalidProgress
}
