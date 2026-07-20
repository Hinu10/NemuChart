import Combine
import StoreKit

@MainActor
final class PremiumEntitlementService: ObservableObject {
    static let monthlyProductID = "com.hinu10.NemuChart.premium.monthly"

    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        product = try? await Product.products(for: [Self.monthlyProductID]).first
        hasPremiumAccess = await currentEntitlementIsActive()
    }

    func purchase() async throws {
        guard let product else { throw PremiumAccessError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            hasPremiumAccess = true
        case .pending, .userCancelled:
            break
        @unknown default:
            break
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        hasPremiumAccess = await currentEntitlementIsActive()
    }

    private func currentEntitlementIsActive() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            if transaction.productID == Self.monthlyProductID,
               transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                return true
            }
        }
        return false
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw PremiumAccessError.failedVerification
        }
    }
}

enum PremiumAccessError: LocalizedError {
    case productUnavailable
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productUnavailable: "購入情報を取得できませんでした。時間をおいて再度お試しください。"
        case .failedVerification: "購入情報を確認できませんでした。"
        }
    }
}
