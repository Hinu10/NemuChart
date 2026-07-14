import Foundation

protocol ScoringServiceProtocol: Sendable {
    func score(record: SleepRecord, settings: UserSettings) throws -> DailySleepScore
}

protocol AnalysisServiceProtocol: Sendable {
    func weeklyReport(records: [SleepRecord], weekStart: SleepDay) throws -> WeeklySleepReport
}

protocol FeedbackServiceProtocol: Sendable {
    func message(for score: DailySleepScore?) -> String
}

protocol SheepStateServiceProtocol: Sendable {
    func state(previous: SheepState, latestScore: DailySleepScore?) -> SheepState
}

