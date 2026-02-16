import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobManager {
    private static var hasStarted = false

    static func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        #if canImport(GoogleMobileAds)
        DispatchQueue.main.async {
            MobileAds.shared.start()
        }
        #endif
    }
}
