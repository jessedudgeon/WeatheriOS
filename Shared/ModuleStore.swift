import Foundation
import StoreKit
import Combine

@MainActor
final class ModuleStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published private(set) var pendingProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isCheckingAccess = true
    @Published private(set) var isRestoring = false
    @Published private(set) var purchasingID: String?
    @Published private(set) var message: String?
    private var listener: Task<Void, Never>?
    private var entitlementRevision = 0
    private var isFixture = false
    private let knownIDs = Set(WeatherModule.allCases.map(\.productID))
    var isBusy: Bool { purchasingID != nil || isRestoring }

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") && !ProcessInfo.processInfo.arguments.contains("--storekit-testing") {
            isFixture = true
            isCheckingAccess = false
            if !ProcessInfo.processInfo.arguments.contains("--locked-modules") {
                ownedProductIDs = Set(WeatherModule.allCases.map(\.productID))
            }
            return
        }
        #endif
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.receive(result)
            }
        }
        Task { [weak self] in await self?.refreshAccess() }
        Task { [weak self] in await self?.loadProducts() }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard let self, self.isCheckingAccess else { return }
            self.isCheckingAccess = false
            self.message = "Checking previous purchases is taking longer than usual. You can try Restore Purchases."
        }
    }
    deinit { listener?.cancel() }

    func owns(_ module: WeatherModule) -> Bool { module.isUnlocked(by: ownedProductIDs) }
    func product(for module: WeatherModule) -> Product? { products.first { $0.id == module.productID } }

    func loadProducts() async {
        guard !isFixture, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: knownIDs).filter { $0.type == .nonConsumable }
        } catch {
            message = "The store couldn’t connect. Your unlocked modules remain available. Try again later."
        }
    }

    func refreshAccess() async {
        guard !isFixture else { return }
        entitlementRevision += 1
        let revision = entitlementRevision
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  knownIDs.contains(transaction.productID), transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            owned.insert(transaction.productID)
        }
        guard revision == entitlementRevision else { return }
        ownedProductIDs = owned
        pendingProductIDs.subtract(owned)
        isCheckingAccess = false
    }

    func purchase(_ module: WeatherModule) async {
        guard !isFixture, !isBusy, !isCheckingAccess, !owns(module),
              !pendingProductIDs.contains(module.productID), let product = product(for: module) else { return }
        guard AppStore.canMakePayments else {
            message = "Purchases aren’t allowed on this device. Check your account or parental controls."
            return
        }
        purchasingID = module.productID
        message = nil
        defer { purchasingID = nil }
        do {
            switch try await product.purchase() {
            case .success(let result): await receive(result)
            case .pending:
                pendingProductIDs.insert(module.productID)
                message = "Purchase pending approval. The module will unlock when Apple confirms it."
            case .userCancelled: break
            @unknown default: message = "The purchase hasn’t completed. Try Restore Purchases to check your access."
            }
        } catch {
            message = "The purchase couldn’t finish. Try again or use Restore Purchases."
        }
    }

    func restore() async {
        guard !isFixture, !isBusy else { return }
        isRestoring = true
        message = nil
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshAccess()
            message = ownedProductIDs.isEmpty ? "No module purchases were found for this Apple Account." : "Your module purchases have been restored."
        } catch {
            message = "Purchases couldn’t be restored. Check your connection and Apple Account, then try again."
        }
    }

    private func receive(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            message = "Apple couldn’t verify this purchase. Access hasn’t changed. Try Restore Purchases."
            return
        }
        guard knownIDs.contains(transaction.productID), transaction.productType == .nonConsumable else { return }
        // Deliver a verified transaction immediately; a receipt-history request
        // must not prevent a successful purchase (or refund) from taking effect.
        entitlementRevision += 1
        pendingProductIDs.remove(transaction.productID)
        if transaction.revocationDate == nil && !transaction.isUpgraded {
            ownedProductIDs.insert(transaction.productID)
            message = "Purchase complete. Your module is unlocked."
        } else {
            ownedProductIDs.remove(transaction.productID)
        }
        isCheckingAccess = false
        await transaction.finish()
        Task { [weak self] in await self?.refreshAccess() }
    }
}
