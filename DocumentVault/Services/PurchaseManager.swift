import Foundation
import OSLog
import Combine
import RevenueCat
import RevenueCatUI
import SwiftUI

@MainActor
final class PurchaseManager: NSObject, ObservableObject {

    static let shared = PurchaseManager()

    static let premiumEntitlementIdentifier = AppConstants.premiumEntitlementIdentifier

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var lastError: PurchaseManagerError?
    @Published private(set) var isConfigured = false
    @Published var showPaywall = false
    @Published var showCustomerCenter = false
    @Published var showPaywallUnavailable = false
    @Published var paywallOffering: Offering?
    @Published var paywallIntent: PaywallIntent = .general
    @Published var shouldResumeAddFamilyMember = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? AppConstants.bundleId,
        category: "RevenueCat"
    )

    private override init() {
        super.init()
    }

    var isPremiumUnlocked: Bool {
        Self.hasPremiumAccess(customerInfo)
    }

    var activePremiumEntitlement: EntitlementInfo? {
        Self.firstActivePremiumEntitlement(in: customerInfo)
    }

    func configure() {
        guard !isConfigured else { return }

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        let apiKey = Self.resolvedPublicAPIKey()
        guard let apiKey, !apiKey.isEmpty else {
            logger.error("RevenueCat: missing API key (set REVENUECAT_PUBLIC_API_KEY in Info.plist).")
            lastError = .configurationMissing
            return
        }

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        logger.debug("RevenueCat Purchases configured.")

        Task { await bootstrapAfterConfigure() }
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
            lastError = nil
        } catch {
            logger.error("RevenueCat customerInfo error: \(error.localizedDescription, privacy: .public)")
            lastError = .network(error)
        }
    }

    func refreshOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            if offerings.current == nil {
                logger.notice("RevenueCat: no current offering configured in the dashboard.")
            }
            lastError = nil
        } catch {
            logger.error("RevenueCat offerings error: \(error.localizedDescription, privacy: .public)")
            lastError = .network(error)
        }
    }

    func showPaywallSheet(offering: Offering? = nil, intent: PaywallIntent = .general) {
        guard isConfigured else {
            showPaywallUnavailable = true
            return
        }
        paywallIntent = intent
        let resolved = offering ?? currentOffering
        if resolved == nil {
            paywallOffering = nil
            showPaywall = true
            Task { await refreshOfferings() }
            return
        }
        paywallOffering = resolved
        showPaywall = true
    }

    func handlePurchaseOrRestoreCompleted(_ updatedCustomerInfo: CustomerInfo? = nil) async {
        if let updatedCustomerInfo {
            applyCustomerInfo(updatedCustomerInfo)
        } else {
            await refreshCustomerInfo()
        }

        if !isPremiumUnlocked {
            do {
                let freshInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
                applyCustomerInfo(freshInfo)
            } catch {
                logger.error("RevenueCat forced refresh error: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard isPremiumUnlocked else {
            logger.error("RevenueCat: purchase completed but premium access is still locked. Check entitlement mapping in dashboard.")
            return
        }

        let intent = paywallIntent
        showPaywall = false
        paywallIntent = .general

        if intent == .addFamilyMember {
            shouldResumeAddFamilyMember = true
        }
    }

    func clearResumeAddFamilyMember() {
        shouldResumeAddFamilyMember = false
    }

    func showCustomerCenterSheet() {
        guard isConfigured else {
            showPaywallUnavailable = true
            return
        }
        showCustomerCenter = true
    }

    private func bootstrapAfterConfigure() async {
        async let customer: Void = refreshCustomerInfo()
        async let offerings: Void = refreshOfferings()
        _ = await (customer, offerings)
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        #if DEBUG
        let activeEntitlements = info.entitlements.active.keys.sorted().joined(separator: ", ")
        let activeSubscriptions = info.activeSubscriptions.sorted().joined(separator: ", ")
        logger.debug("RevenueCat entitlements=[\(activeEntitlements, privacy: .public)] subscriptions=[\(activeSubscriptions, privacy: .public)] premiumUnlocked=\(self.isPremiumUnlocked)")
        #endif
    }

    static func hasPremiumAccess(_ customerInfo: CustomerInfo?) -> Bool {
        guard let customerInfo else { return false }

        if firstActivePremiumEntitlement(in: customerInfo) != nil {
            return true
        }

        return !customerInfo.activeSubscriptions
            .intersection(AppConstants.premiumProductIdentifiers)
            .isEmpty
    }

    static func firstActivePremiumEntitlement(in customerInfo: CustomerInfo?) -> EntitlementInfo? {
        guard let customerInfo else { return nil }

        for identifier in AppConstants.fallbackPremiumEntitlementIdentifiers {
            if let entitlement = customerInfo.entitlements[identifier], entitlement.isActive {
                return entitlement
            }
        }

        return nil
    }

    private static func resolvedPublicAPIKey() -> String? {
        let key = AppConstants.revenueCatPublicAPIKey
        return key.isEmpty ? nil : key
    }
}

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.applyCustomerInfo(customerInfo)
        }
    }
}

enum PaywallIntent: Equatable {
    case general
    case addFamilyMember
}

enum PurchaseManagerError {
    case configurationMissing
    case userCancelled
    case network(Error)
}

struct DocumentVaultPaywallView: View {
    let offering: Offering
    let onDismiss: () -> Void

    var body: some View {
        PaywallView(offering: offering, displayCloseButton: true)
            .onRequestedDismissal(onDismiss)
            .onPurchaseCompleted { customerInfo in
                Task { await PurchaseManager.shared.handlePurchaseOrRestoreCompleted(customerInfo) }
            }
            .onRestoreCompleted { customerInfo in
                Task { await PurchaseManager.shared.handlePurchaseOrRestoreCompleted(customerInfo) }
            }
    }
}

struct DocumentVaultCustomerCenterView: View {
    let onDismiss: () -> Void

    var body: some View {
        CustomerCenterView(
            navigationOptions: CustomerCenterNavigationOptions(onCloseHandler: onDismiss)
        )
        .onCustomerCenterRestoreCompleted { customerInfo in
            Task { await PurchaseManager.shared.handlePurchaseOrRestoreCompleted(customerInfo) }
        }
    }
}
