import Foundation
import StoreKit

@MainActor
final class PremiumManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var displayPrice: String = "$2/month"
    @Published private(set) var lastErrorMessage: String? = nil

    private let productId: String
    private var product: Product?
    private var isObservingTransactions: Bool = false
    private let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    init(productId: String = "com.axellangenskiold.minicrossword.premium_monthly") {
        self.productId = productId
    }

    func loadProduct() async {
        if let testError = StoreKitTestSessionManager.startIfNeeded(), isSimulator {
            lastErrorMessage = testError
            return
        }
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
                if lastErrorMessage == nil {
                    if isSimulator {
                        lastErrorMessage = "Subscription not found. Check StoreKit config is selected in the scheme."
                    } else {
                        lastErrorMessage = "Subscription not found. On device, use App Store Connect sandbox or TestFlight."
                    }
                }
                return
            }
            self.product = product
            self.displayPrice = "\(product.displayPrice)/month"
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == productId else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() {
                continue
            }
            if transaction.revocationDate != nil {
                continue
            }
            hasPremium = true
        }
        isPremium = hasPremium
    }

    func purchase() async -> Bool {
        lastErrorMessage = nil
        guard let product else {
            await loadProduct()
            guard let product else { return false }
            self.product = product
            self.displayPrice = "\(product.displayPrice)/month"
            return await purchase()
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPremium
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func startObservingTransactions() {
        guard !isObservingTransactions else { return }
        isObservingTransactions = true
        Task(priority: .background) {
            await self.observeTransactions()
        }
    }

    private func observeTransactions() async {
        for await _ in Transaction.updates {
            await refreshEntitlements()
        }
    }
}
