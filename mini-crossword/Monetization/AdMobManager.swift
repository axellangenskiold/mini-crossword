import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobManager {
    static func start() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif
    }
}
