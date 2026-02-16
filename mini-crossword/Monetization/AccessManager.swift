import Combine
import Foundation
import UIKit

@MainActor
final class AccessManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var premiumPrice: String = "$2/month"
    @Published private(set) var isAdProcessing: Bool = false
    @Published private(set) var isPurchaseProcessing: Bool = false
    @Published private(set) var isRestoreProcessing: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let unlockStore: PuzzleUnlockStoring
    private var unlocked: Set<String> = []
    private let premiumManager: PremiumManager
    private let adManager: RewardedAdManager
    private var cancellables: Set<AnyCancellable> = []
    private var hasLoaded: Bool = false
    private var hasPreloadedAd: Bool = false
    private var shouldPreloadAds: Bool = false

    init(
        unlockStore: PuzzleUnlockStoring? = nil,
        premiumManager: PremiumManager? = nil,
        adManager: RewardedAdManager? = nil
    ) {
        if let unlockStore {
            self.unlockStore = unlockStore
        } else {
            self.unlockStore = (try? FilePuzzleUnlockStore()) ?? InMemoryPuzzleUnlockStore()
        }
        self.premiumManager = premiumManager ?? PremiumManager()
        self.adManager = adManager ?? RewardedAdManager()
        bindPremiumUpdates()
    }

    func warmUp(preloadAds: Bool) {
        if preloadAds {
            shouldPreloadAds = true
        }
        guard !hasLoaded else {
            if preloadAds {
                preloadAdIfNeeded()
            }
            return
        }
        hasLoaded = true
        Task(priority: .background) { [weak self] in
            await self?.load()
        }
        premiumManager.startObservingTransactions()
    }

    func load() async {
        unlocked = (try? unlockStore.loadUnlocks()) ?? []
        premiumPrice = premiumManager.displayPrice
        isPremium = premiumManager.isPremium
        await premiumManager.loadProduct()
        await premiumManager.refreshEntitlements()
        premiumPrice = premiumManager.displayPrice
        isPremium = premiumManager.isPremium
        if shouldPreloadAds {
            preloadAdIfNeeded()
        }
    }

    func prepareAd() {
        adManager.load()
    }

    func canAccess(puzzleKey: String) -> Bool {
        isPremium || unlocked.contains(puzzleKey)
    }

    func unlockWithAd(puzzleKey: String) async -> Bool {
        lastErrorMessage = nil
        isAdProcessing = true
        defer { isAdProcessing = false }

        let success = await withCheckedContinuation { continuation in
            adManager.show(from: rootViewController()) { rewarded in
                continuation.resume(returning: rewarded)
            }
        }

        if success {
            unlocked.insert(puzzleKey)
            try? unlockStore.saveUnlocks(unlocked)
            return true
        }

        lastErrorMessage = adManager.lastErrorMessage ?? "Ad could not be shown."
        return false
    }

    func purchasePremium() async -> Bool {
        lastErrorMessage = nil
        isPurchaseProcessing = true
        defer { isPurchaseProcessing = false }

        let success = await premiumManager.purchase()
        isPremium = premiumManager.isPremium
        premiumPrice = premiumManager.displayPrice
        if !success, let message = premiumManager.lastErrorMessage {
            lastErrorMessage = message
        }
        return success
    }

    func restorePurchases() async {
        lastErrorMessage = nil
        isRestoreProcessing = true
        defer { isRestoreProcessing = false }

        await premiumManager.restore()
        isPremium = premiumManager.isPremium
        premiumPrice = premiumManager.displayPrice
        if let message = premiumManager.lastErrorMessage {
            lastErrorMessage = message
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func preloadAdIfNeeded() {
        guard !hasPreloadedAd else { return }
        guard !isPremium else { return }
        hasPreloadedAd = true
        adManager.load()
    }

    private func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let keyWindow = windowScene?.windows.first { $0.isKeyWindow }
        return keyWindow?.rootViewController
    }

    private func bindPremiumUpdates() {
        premiumManager.$displayPrice
            .receive(on: RunLoop.main)
            .sink { [weak self] price in
                self?.premiumPrice = price
            }
            .store(in: &cancellables)

        premiumManager.$isPremium
            .receive(on: RunLoop.main)
            .sink { [weak self] premium in
                self?.isPremium = premium
            }
            .store(in: &cancellables)

        premiumManager.$lastErrorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.lastErrorMessage = message
            }
            .store(in: &cancellables)
    }
}

private struct InMemoryPuzzleUnlockStore: PuzzleUnlockStoring {
    func loadUnlocks() throws -> Set<String> {
        []
    }

    func saveUnlocks(_ ids: Set<String>) throws {
    }
}
