import StoreKit
import UIKit

@MainActor
enum AppReviewManager {
    private static let documentSaveCountKey = "reviewDocumentSaveCount"
    private static let lastPromptVersionKey = "reviewLastPromptVersion"

    /// Call after the user saves a document — may show the native review prompt at milestones.
    static func recordDocumentSaved() {
        guard !AppConstants.appStoreId.isEmpty else { return }

        let count = UserDefaults.standard.integer(forKey: documentSaveCountKey) + 1
        UserDefaults.standard.set(count, forKey: documentSaveCountKey)

        if count == 3 || count == 10 {
            requestReviewIfAppropriate()
        }
    }

    /// Shows the native in-app review prompt (at most once per app version).
    static func requestReviewIfAppropriate() {
        guard !AppConstants.appStoreId.isEmpty else { return }

        let version = AppConstants.appVersion
        guard UserDefaults.standard.string(forKey: lastPromptVersionKey) != version else { return }

        requestReview()
        UserDefaults.standard.set(version, forKey: lastPromptVersionKey)
    }

    static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        AppStore.requestReview(in: scene)
    }

    /// Opens the App Store write-review page — use for explicit "Rate App" taps.
    static func openAppStoreReviewPage() {
        UIApplication.shared.open(AppConstants.appStoreReviewURL)
    }
}
