import SwiftData
import XCTest
@testable import NemuChart

@MainActor
final class SwiftDataRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataSleepRecordRepository!
    private let updateTime = TestFixtures.date(2026, 7, 15, 12, 0)

    override func setUpWithError() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        repository = SwiftDataSleepRecordRepository(
            context: container.mainContext,
            clock: Clock(now: { [updateTime] in updateTime })
        )
    }

    override func tearDownWithError() throws {
        repository = nil
        container = nil
    }

    func testCreateReadUpdateAndDelete() throws {
        let original = try TestFixtures.sleepRecord()
        guard case .created(let created) = try repository.save(original) else {
            return XCTFail("新規保存になる必要があります")
        }
        XCTAssertEqual(created.id, original.id)
        XCTAssertEqual(try repository.record(id: original.id), created)

        let edited = try TestFixtures.sleepRecord(
            id: original.id,
            freshness: .veryRefreshed,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt
        )
        guard case .updated(let updated) = try repository.save(edited) else {
            return XCTFail("同一IDは更新になる必要があります")
        }
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, original.createdAt)
        XCTAssertEqual(updated.updatedAt, updateTime)
        XCTAssertEqual(updated.freshness, .veryRefreshed)

        try repository.delete(id: original.id)
        XCTAssertNil(try repository.record(id: original.id))
    }

    func testCanCreateMultipleRecordsForSameSleepDayDuringImplementation() throws {
        let existing = try TestFixtures.sleepRecord()
        _ = try repository.save(existing)
        let duplicate = try TestFixtures.sleepRecord(id: UUID(), freshness: .veryTired)

        guard case .created(let created) = try repository.save(duplicate) else {
            return XCTFail("実装中は同じ睡眠日の新規IDも保存できる必要があります")
        }
        XCTAssertEqual(created.id, duplicate.id)
        XCTAssertEqual(try repository.records().count, 2)
    }

    func testCanRecreateAfterDeletion() throws {
        let first = try TestFixtures.sleepRecord()
        _ = try repository.save(first)
        try repository.delete(id: first.id)

        let replacement = try TestFixtures.sleepRecord(id: UUID())
        guard case .created = try repository.save(replacement) else {
            return XCTFail("削除後は同じ睡眠日に再作成できる必要があります")
        }
    }

    func testInMemoryStoresAreIsolated() throws {
        _ = try repository.save(TestFixtures.sleepRecord())
        let otherContainer = try ModelContainerFactory.make(inMemory: true)
        let otherRepository = SwiftDataSleepRecordRepository(context: otherContainer.mainContext)

        XCTAssertEqual(try repository.records().count, 1)
        XCTAssertTrue(try otherRepository.records().isEmpty)
    }

    func testDiskStoreSurvivesContainerRecreation() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        var firstContainer: ModelContainer? = try ModelContainerFactory.make(storeURL: storeURL)
        var firstRepository: SwiftDataSleepRecordRepository? = SwiftDataSleepRecordRepository(
            context: firstContainer!.mainContext
        )
        let record = try TestFixtures.sleepRecord()
        _ = try firstRepository!.save(record)
        firstRepository = nil
        firstContainer = nil

        let reopenedContainer = try ModelContainerFactory.make(storeURL: storeURL)
        let reopenedRepository = SwiftDataSleepRecordRepository(
            context: reopenedContainer.mainContext
        )

        XCTAssertEqual(try reopenedRepository.record(id: record.id), record)
    }

    func testSettingsAndGoalRepositoriesRoundTrip() throws {
        let settingsRepository = SwiftDataUserSettingsRepository(context: container.mainContext)
        let goalRepository = SwiftDataSleepGoalRepository(context: container.mainContext)
        let settings = try UserSettings(
            hasCompletedOnboarding: true,
            desiredSleepDuration: 8 * 60 * 60,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!,
            averageSleepLatencyMinutes: nil
        )
        let goal = try SleepGoal(
            targetBedTime: LocalTime(hour: 22, minute: 45)!,
            targetSleepTime: LocalTime(hour: 23, minute: 0)!,
            targetWakeTime: LocalTime(hour: 7, minute: 0)!,
            timeZoneIdentifier: "Asia/Tokyo"
        )

        try settingsRepository.save(settings)
        try goalRepository.save(goal)

        XCTAssertEqual(try settingsRepository.load(), settings)
        XCTAssertEqual(try goalRepository.goal(id: goal.id), goal)
    }

    func testDeleteAllRemovesRecordsGoalsSettingsAndPreferences() throws {
        let settingsRepository = SwiftDataUserSettingsRepository(context: container.mainContext)
        let goalRepository = SwiftDataSleepGoalRepository(context: container.mainContext)
        let settings = try UserSettings(
            hasCompletedOnboarding: true,
            desiredSleepDuration: 8 * 3600,
            standardWakeTime: LocalTime(hour: 7, minute: 0)!
        )
        let goal = try SleepGoal(
            targetBedTime: LocalTime(hour: 22, minute: 30)!,
            targetSleepTime: LocalTime(hour: 23, minute: 0)!,
            targetWakeTime: LocalTime(hour: 7, minute: 0)!,
            timeZoneIdentifier: "Asia/Tokyo"
        )
        _ = try repository.save(TestFixtures.sleepRecord())
        try settingsRepository.save(settings)
        try goalRepository.save(goal)

        let suiteName = "NemuChartTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AppPreferencesStore(defaults: defaults)
        var preferenceData = preferences.load()
        preferenceData.actionGoal = .putPhoneAway
        try preferences.save(preferenceData)

        try DataDeletionService(
            sleepRecordRepository: repository,
            userSettingsRepository: settingsRepository,
            sleepGoalRepository: goalRepository,
            preferences: preferences
        ).deleteAll()

        XCTAssertTrue(try repository.records().isEmpty)
        XCTAssertTrue(try goalRepository.goals().isEmpty)
        XCTAssertNil(try settingsRepository.load())
        XCTAssertEqual(preferences.load(), AppPreferenceData())
    }
}
