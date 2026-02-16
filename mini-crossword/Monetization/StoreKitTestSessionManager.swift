import Foundation

#if DEBUG && canImport(StoreKitTest)
import StoreKitTest
#endif

@MainActor
enum StoreKitTestSessionManager {
    private static var hasStarted = false
    #if DEBUG && canImport(StoreKitTest)
    private static var session: SKTestSession?
    #endif

    @discardableResult
    static func startIfNeeded() -> String? {
        guard !hasStarted else { return nil }
        hasStarted = true
        #if DEBUG && canImport(StoreKitTest) && targetEnvironment(simulator)
        guard let url = Bundle.main.url(forResource: "StoreKitConfig", withExtension: "storekit") else {
            return "StoreKit config not found in app bundle."
        }
        do {
            let testSession = try SKTestSession(contentsOf: url)
            testSession.disableDialogs = false
            testSession.askToBuyEnabled = false
            testSession.timeRate = .realTime
            session = testSession
        } catch {
            return "StoreKit test session failed: \(error.localizedDescription)"
        }
        return nil
        #else
        return "StoreKit test session is only available on Simulator."
        #endif
    }
}
