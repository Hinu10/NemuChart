import Foundation
import SwiftData

@MainActor
final class SwiftDataSleepRecordRepository: SleepRecordRepository {
    private let context: ModelContext
    private let clock: Clock

    init(context: ModelContext, clock: Clock = .live) {
        self.context = context
        self.clock = clock
    }

    func records() throws -> [SleepRecord] {
        do {
            let entities = try context.fetch(FetchDescriptor<SleepRecordEntity>())
            return try entities.map { try $0.domainModel() }.sorted { $0.sleepDay > $1.sleepDay }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    func record(id: UUID) throws -> SleepRecord? {
        try entities().first(where: { $0.id == id })?.domainModel()
    }

    func record(for sleepDay: SleepDay) throws -> SleepRecord? {
        try entities().first(where: { $0.sleepDayKey == sleepDay.key })?.domainModel()
    }

    func save(_ record: SleepRecord) throws -> SleepRecordSaveResult {
        do {
            let stored = try entities()
            if let existingByID = stored.first(where: { $0.id == record.id }) {
                try existingByID.update(from: record, at: clock.now())
                try context.save()
                return .updated(try existingByID.domainModel())
            }

            let entity = try SleepRecordEntity(record: record)
            context.insert(entity)
            try context.save()
            return .created(try entity.domainModel())
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    func delete(id: UUID) throws {
        do {
            guard let entity = try entities().first(where: { $0.id == id }) else {
                throw RepositoryError.notFound
            }
            context.delete(entity)
            try context.save()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    private func entities() throws -> [SleepRecordEntity] {
        do {
            return try context.fetch(FetchDescriptor<SleepRecordEntity>())
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }
}

@MainActor
final class SwiftDataUserSettingsRepository: UserSettingsRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func load() throws -> UserSettings? {
        do {
            return try context.fetch(FetchDescriptor<UserSettingsEntity>()).first?.domainModel()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    func save(_ settings: UserSettings) throws {
        do {
            let entities = try context.fetch(FetchDescriptor<UserSettingsEntity>())
            if let entity = entities.first(where: { $0.id == settings.id }) {
                entity.update(from: settings)
            } else {
                context.insert(UserSettingsEntity(settings: settings))
            }
            try context.save()
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    func delete() throws {
        do {
            let entities = try context.fetch(FetchDescriptor<UserSettingsEntity>())
            entities.forEach(context.delete)
            try context.save()
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }
}

@MainActor
final class SwiftDataSleepGoalRepository: SleepGoalRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func goals() throws -> [SleepGoal] {
        do {
            return try context.fetch(FetchDescriptor<SleepGoalEntity>())
                .map { try $0.domainModel() }
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    func goal(id: UUID) throws -> SleepGoal? {
        try goals().first(where: { $0.id == id })
    }

    func save(_ goal: SleepGoal) throws {
        do {
            let entities = try context.fetch(FetchDescriptor<SleepGoalEntity>())
            if let entity = entities.first(where: { $0.id == goal.id }) {
                entity.update(from: goal)
            } else {
                context.insert(SleepGoalEntity(goal: goal))
            }
            try context.save()
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }

    func delete(id: UUID) throws {
        do {
            let entities = try context.fetch(FetchDescriptor<SleepGoalEntity>())
            guard let entity = entities.first(where: { $0.id == id }) else {
                throw RepositoryError.notFound
            }
            context.delete(entity)
            try context.save()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(error.localizedDescription)
        }
    }
}
