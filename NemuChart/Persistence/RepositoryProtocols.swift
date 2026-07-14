import Foundation

enum SleepRecordSaveResult: Equatable, Sendable {
    case created(SleepRecord)
    case updated(SleepRecord)
    case duplicate(existing: SleepRecord)
}

enum RepositoryError: Error, Equatable, LocalizedError {
    case notFound
    case invalidStoredData(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: "対象のデータが見つかりません。"
        case .invalidStoredData(let reason): "保存データを読み取れません: \(reason)"
        case .persistenceFailed(let reason): "データを保存できません: \(reason)"
        }
    }
}

@MainActor
protocol SleepRecordRepository: AnyObject {
    func records() throws -> [SleepRecord]
    func record(id: UUID) throws -> SleepRecord?
    func record(for sleepDay: SleepDay) throws -> SleepRecord?
    func save(_ record: SleepRecord) throws -> SleepRecordSaveResult
    func delete(id: UUID) throws
}

@MainActor
protocol UserSettingsRepository: AnyObject {
    func load() throws -> UserSettings?
    func save(_ settings: UserSettings) throws
    func delete() throws
}

@MainActor
protocol SleepGoalRepository: AnyObject {
    func goals() throws -> [SleepGoal]
    func goal(id: UUID) throws -> SleepGoal?
    func save(_ goal: SleepGoal) throws
    func delete(id: UUID) throws
}

