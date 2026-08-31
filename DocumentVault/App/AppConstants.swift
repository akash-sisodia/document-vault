import Foundation
import SwiftUI

enum AppConstants {
    static let displayName = "Doksy"
    static let tagline = "Understand every document."
    static let bundleId = "com.app.documentvault"
    /// Replace with the live App Store numeric ID after the first listing is created.
    static let appStoreId = "6803893515"
    static let privacyPolicyURL = URL(string: "https://sites.google.com/view/documentvaultapp/home")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let subscriptionsManagementURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let supportEmail = "info@hexalitics.com"
    static let developerWebsiteURL = URL(string: "https://www.hexalitics.com/")!

    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreId)")!
    }

    static var appStoreReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreId)?action=write-review")!
    }

    /// FeedJar app key from Info.plist (injected via Config/Secrets.xcconfig).
    static var feedJarAPIKey: String {
        plistString("FEEDJAR_API_KEY")
    }

    /// RevenueCat Apple public SDK key from Info.plist (injected via Config/Secrets.xcconfig).
    static var revenueCatPublicAPIKey: String {
        plistString("REVENUECAT_PUBLIC_API_KEY")
    }

    /// Must match the entitlement Identifier in the RevenueCat dashboard.
    static let premiumEntitlementIdentifier = "Doksy Pro"

    /// Alternate entitlement IDs sometimes used in RevenueCat before Doksy rebrand.
    static let fallbackPremiumEntitlementIdentifiers = [
        "Doksy Pro",
        "Document Vault Pro",
        "documentvault_pro",
        "pro",
        "premium"
    ]

    /// App Store product IDs that unlock Doksy Pro.
    static let premiumProductIdentifiers: Set<String> = [
        "com.app.documentvault.monthly",
        "com.app.documentvault.annual",
        "com.app.documentvault.lifetime"
    ]

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private static func plistString(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

extension Color {
    /// Brand primary — #FF6A3D
    static let doksyPrimary = Color(red: 1.0, green: 106 / 255, blue: 61 / 255)
    /// Brand secondary — #FFB29A
    static let doksySecondary = Color(red: 1.0, green: 178 / 255, blue: 154 / 255)
    /// Brand background — #FFFAF2
    static let doksyBackground = Color(red: 1.0, green: 250 / 255, blue: 242 / 255)
    /// Brand surface — #F1E6DA
    static let doksySurface = Color(red: 241 / 255, green: 230 / 255, blue: 218 / 255)
    /// Brand forest (text) — #3A2A24
    static let doksyForest = Color(red: 58 / 255, green: 42 / 255, blue: 36 / 255)

    static let vaultAccent = doksyPrimary
}
