import Foundation
import Combine
import StoreKit

/// StoreKit 2 wrapper for the "StreakMed Plus" tier.
///
/// Entitlement is derived from `Transaction.currentEntitlements` (works offline
/// from the device's receipt cache) and mirrored to UserDefaults so the first
/// frame after launch doesn't flash the free tier for a paying user.
///
/// Product IDs must match App Store Connect exactly.
@MainActor
final class PlusStore: ObservableObject {
    static let shared = PlusStore()

    enum ProductID {
        static let monthly  = "com.zacharyhuff.StreakMed.plus.monthly"
        static let yearly   = "com.zacharyhuff.StreakMed.plus.yearly"
        static let lifetime = "com.zacharyhuff.StreakMed.plus.lifetime"
        static let all      = [monthly, yearly, lifetime]
    }

    private static let cacheKey = "plusActiveCache"

    @Published private(set) var products: [Product] = []
    @Published private(set) var hasEntitlement: Bool
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var lastError: String?

    #if DEBUG
    /// Dev Tools override so Plus features can be exercised without a sandbox account.
    @Published var debugForcePlus: Bool = UserDefaults.standard.bool(forKey: "debugForcePlus") {
        didSet { UserDefaults.standard.set(debugForcePlus, forKey: "debugForcePlus") }
    }
    #endif

    /// The single gate every Plus feature checks.
    var isPlus: Bool {
        #if DEBUG
        if debugForcePlus { return true }
        #endif
        return hasEntitlement
    }

    private var updatesTask: Task<Void, Never>?

    private init() {
        hasEntitlement = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updatesTask = listenForTransactions()
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    // MARK: - Products

    var monthly:  Product? { products.first { $0.id == ProductID.monthly } }
    var yearly:   Product? { products.first { $0.id == ProductID.yearly } }
    var lifetime: Product? { products.first { $0.id == ProductID.lifetime } }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: ProductID.all)
            // Keep a stable display order regardless of what the store returns.
            products = ProductID.all.compactMap { id in fetched.first { $0.id == id } }
        } catch {
            lastError = "Couldn't load plans. Check your connection and try again."
        }
    }

    // MARK: - Purchase / restore

    /// Returns true when the purchase completed and the entitlement is now active.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Purchase couldn't be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPlus
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed. Please try again."
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            // sync() throws when the user cancels the sign-in prompt; entitlements
            // are still re-read below from whatever the device already has.
        }
        await refreshEntitlements()
        if !isPlus { lastError = "No previous purchase found for this Apple Account." }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  ProductID.all.contains(t.productID),
                  t.revocationDate == nil else { continue }
            active = true
        }
        if active != hasEntitlement {
            hasEntitlement = active
            UserDefaults.standard.set(active, forKey: Self.cacheKey)
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
