import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds

@MainActor
final class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private var rewardedAd: RewardedAd?
    private var rewardCompletion: ((Bool) -> Void)? = nil
    private var didEarnReward: Bool = false

    func load() {
        lastErrorMessage = nil
        RewardedAd.load(with: AdMobConfiguration.rewardedAdUnitId, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                self.lastErrorMessage = error.localizedDescription
                self.isReady = false
                self.rewardedAd = nil
                return
            }
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.isReady = ad != nil
        }
    }

    func show(from rootViewController: UIViewController?, onReward: @escaping (Bool) -> Void) {
        guard let rootViewController else {
            lastErrorMessage = "Ad could not be shown."
            onReward(false)
            return
        }
        guard let rewardedAd else {
            lastErrorMessage = "Ad is not ready."
            onReward(false)
            load()
            return
        }
        rewardCompletion = onReward
        didEarnReward = false
        rewardedAd.present(from: rootViewController) { [weak self] in
            self?.didEarnReward = true
        }
        self.rewardedAd = nil
        self.isReady = false
        load()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let rewardCompletion {
            rewardCompletion(didEarnReward)
        }
        rewardCompletion = nil
        didEarnReward = false
        load()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastErrorMessage = error.localizedDescription
        isReady = false
        rewardCompletion?(false)
        rewardCompletion = nil
        didEarnReward = false
    }
}
#else
@MainActor
final class RewardedAdManager: ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var lastErrorMessage: String? = "Ad SDK not linked."

    func load() {
        isReady = false
    }

    func show(from rootViewController: UIViewController?, onReward: @escaping (Bool) -> Void) {
        lastErrorMessage = "Ad SDK not linked."
        onReward(false)
    }
}
#endif
