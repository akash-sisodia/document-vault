import RevenueCat
import SwiftUI

struct PurchasePresentationModifier: ViewModifier {
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $purchaseManager.showPaywall) {
                paywallSheet
            }
            .sheet(isPresented: $purchaseManager.showCustomerCenter) {
                DocumentVaultCustomerCenterView {
                    purchaseManager.showCustomerCenter = false
                }
            }
            .alert(
                "Purchases Unavailable",
                isPresented: $purchaseManager.showPaywallUnavailable
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Subscriptions aren't available right now. Check your connection and try again.")
            }
    }

    @ViewBuilder
    private var paywallSheet: some View {
        if let offering = purchaseManager.paywallOffering ?? purchaseManager.currentOffering {
            DocumentVaultPaywallView(offering: offering) {
                purchaseManager.showPaywall = false
            }
        } else {
            PaywallLoadingView {
                purchaseManager.showPaywall = false
            }
        }
    }
}

extension View {
    func purchasePresentation() -> some View {
        modifier(PurchasePresentationModifier())
    }
}

private struct PaywallLoadingView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await PurchaseManager.shared.refreshOfferings()
                    if PurchaseManager.shared.currentOffering == nil {
                        PurchaseManager.shared.showPaywall = false
                        PurchaseManager.shared.showPaywallUnavailable = true
                    }
                }
                .navigationTitle("\(AppConstants.displayName) Pro")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onDismiss)
                    }
                }
        }
    }
}
