import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobManager {
    static func start() {
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif
    }
}
