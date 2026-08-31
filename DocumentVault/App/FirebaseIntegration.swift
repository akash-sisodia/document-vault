import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum FirebaseIntegration {
    private(set) static var isConfigured = false

    static func configure() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif

        isConfigured = true

        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        #endif
    }

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        guard isConfigured else { return }
        Analytics.logEvent(name, parameters: parameters)
        #endif
    }

    static func setUserID(_ userID: String?) {
        #if canImport(FirebaseAnalytics)
        guard isConfigured else { return }
        Analytics.setUserID(userID)
        #endif

        #if canImport(FirebaseCrashlytics)
        guard isConfigured else { return }
        Crashlytics.crashlytics().setUserID(userID)
        #endif
    }

    static func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        guard isConfigured else { return }
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
        #endif
    }

    static func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        guard isConfigured else { return }
        Crashlytics.crashlytics().log(message)
        #endif
    }
}
