import SwiftUI

struct UpdateAvailableAlertModifier: ViewModifier {
    @ObservedObject private var updateManager = InAppUpdateManager.shared

    func body(content: Content) -> some View {
        content
            .alert("Update Available", isPresented: $updateManager.showUpdateAlert) {
                Button("Update") {
                    updateManager.performUpdate()
                }
                Button("Remind Me Later") {
                    updateManager.remindLater()
                }
                Button("Skip This Version", role: .cancel) {
                    if let version = updateManager.availableStoreVersion {
                        updateManager.skipUpdate(version: version)
                    }
                }
            } message: {
                if let version = updateManager.availableStoreVersion {
                    Text("A new version of \(AppConstants.displayName) (\(version)) is available on the App Store.")
                } else {
                    Text("A new version of \(AppConstants.displayName) is available on the App Store.")
                }
            }
    }
}

extension View {
    func updateAvailableAlert() -> some View {
        modifier(UpdateAvailableAlertModifier())
    }
}
