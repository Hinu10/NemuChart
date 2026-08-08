import XCTest
@testable import NemuChart

final class MonetizationTests: XCTestCase {
    func testLocalStoreKitConfigurationUsesRuntimePremiumProductID() throws {
        let storeKitURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NemuChart/StoreKit/NemuChartPremium.storekit")
        let data = try Data(contentsOf: storeKitURL)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let groups = root?["subscriptionGroups"] as? [[String: Any]]
        let subscriptions = groups?.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
        let productIDs = subscriptions?.compactMap { $0["productID"] as? String } ?? []

        XCTAssertTrue(productIDs.contains(PremiumEntitlementService.monthlyProductID))
        XCTAssertEqual(productIDs.filter { $0 == PremiumEntitlementService.monthlyProductID }.count, 1)
    }

    func testLocalStoreKitConfigurationHasJapanesePremiumMetadata() throws {
        let storeKitURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NemuChart/StoreKit/NemuChartPremium.storekit")
        let data = try Data(contentsOf: storeKitURL)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let groups = root?["subscriptionGroups"] as? [[String: Any]]
        let subscriptions = groups?.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
        let premium = try XCTUnwrap(subscriptions?.first {
            ($0["productID"] as? String) == PremiumEntitlementService.monthlyProductID
        })

        XCTAssertEqual(premium["recurringSubscriptionPeriod"] as? String, "P1M")
        XCTAssertEqual(premium["type"] as? String, "RecurringSubscription")
        XCTAssertFalse((premium["displayPrice"] as? String ?? "").isEmpty)

        let localizations = premium["localizations"] as? [[String: Any]]
        let japanese = localizations?.first { ($0["locale"] as? String) == "ja_JP" }
        XCTAssertEqual(japanese?["displayName"] as? String, "ねむちゃーと プレミアム（月額）")
    }
}
