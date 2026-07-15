import XCTest
@testable import NemuChart

final class FutureFeatureTests: XCTestCase {
    func testLifestyleAnalysisRequiresBothComparisonGroups() throws {
        let records = try (0..<10).map { index in
            try makeRecord(
                daysBeforeEnd: index,
                freshness: index < 5 ? .veryRefreshed : .tired,
                factors: SleepFactors(consumedAlcohol: index < 5)
            )
        }
        let result = LifestyleAssociationService().analyze(records: records)
        let alcohol = try XCTUnwrap(result.first { $0.factor == .alcohol })
        XCTAssertEqual(alcohol.exposedCount, 5)
        XCTAssertEqual(alcohol.comparisonCount, 5)
        XCTAssertEqual(alcohol.freshnessDifference, 3, accuracy: 0.001)
        XCTAssertEqual(alcohol.confidence, .low)
    }

    func testMissingLifestyleValuesAreNotTreatedAsFalse() throws {
        let records = try (0..<9).map { index in
            try makeRecord(
                daysBeforeEnd: index,
                freshness: .neutral,
                factors: SleepFactors(consumedCaffeine: index < 5 ? true : nil)
            )
        }
        XCTAssertTrue(LifestyleAssociationService().analyze(records: records).isEmpty)
    }

    func testExportsPreserveMissingFalseAndZero() throws {
        let missing = try makeRecord(daysBeforeEnd: 1, factors: SleepFactors())
        let explicit = try makeRecord(
            daysBeforeEnd: 0,
            factors: SleepFactors(awakeningCount: 0, consumedAlcohol: false)
        )
        let service = SleepDataExportService()
        let csv = String(decoding: service.csv(records: [missing, explicit]), as: UTF8.self)
        XCTAssertTrue(csv.contains(",0,"))
        XCTAssertTrue(csv.contains(",false,"))
        XCTAssertTrue(csv.contains("timeZone"))

        let object = try JSONSerialization.jsonObject(with: service.json(records: [missing, explicit])) as! [[String: Any]]
        XCTAssertEqual(object.count, 2)
        let factors = object[1]["factors"] as! [String: Any]
        XCTAssertEqual(factors["awakeningCount"] as? Int, 0)
        XCTAssertEqual(factors["consumedAlcohol"] as? Bool, false)
    }

    func testLongTermReportThresholdAndBuckets() throws {
        let thirteen = try (0..<13).map { try makeRecord(daysBeforeEnd: $0) }
        let end = TestFixtures.date(2026, 7, 15, 12, 0)
        let service = LongTermReportService()
        XCTAssertNil(service.report(records: thirteen, days: 30, endingAt: end))

        let records = try (0..<20).map { try makeRecord(daysBeforeEnd: $0) }
        let report = try XCTUnwrap(service.report(records: records, days: 30, endingAt: end))
        XCTAssertEqual(report.recordCount, 20)
        XCTAssertFalse(report.monthly.isEmpty)
        XCTAssertFalse(report.weekdays.isEmpty)
        XCTAssertEqual(report.timeZoneCount, 1)
    }

    private func makeRecord(
        daysBeforeEnd: Int,
        freshness: Freshness = .refreshed,
        factors: SleepFactors = try! SleepFactors()
    ) throws -> SleepRecord {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TestFixtures.tokyo
        let wake = calendar.date(byAdding: .day, value: -daysBeforeEnd, to: TestFixtures.date(2026, 7, 15, 7, 0))!
        let sleepStart = calendar.date(byAdding: .hour, value: -7, to: wake)!
        let bed = calendar.date(byAdding: .minute, value: -30, to: sleepStart)!
        let sleepDay = try DateTimeService().sleepDay(for: wake, timeZoneIdentifier: "Asia/Tokyo")
        return try SleepRecord(
            sleepDay: sleepDay,
            bedTime: bed,
            sleepStart: sleepStart,
            wakeTime: wake,
            freshness: freshness,
            factors: factors,
            createdAt: wake,
            updatedAt: wake
        )
    }
}

@MainActor
final class AppPreferenceMigrationTests: XCTestCase {
    func testOldPreferenceJSONLoadsWithAlarmDefaults() throws {
        let suite = "NemuChartTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let oldJSON = "{\"rewardedWeeklyGoalIDs\":[]}".data(using: .utf8)!
        defaults.set(oldJSON, forKey: "NemuChart.AppPreferenceData.v1")

        let loaded = AppPreferencesStore(defaults: defaults).load()
        XCTAssertEqual(loaded.alarmSound, .system)
        XCTAssertTrue(loaded.alarmResults.isEmpty)
    }
}
