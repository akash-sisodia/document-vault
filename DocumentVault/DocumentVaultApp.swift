import SwiftUI
import SwiftData

@main
struct DocumentVaultApp: App {
    init() {
        FirebaseIntegration.configure()
        FeedJarIntegration.configure()
        PurchaseManager.shared.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Profile.self,
            VaultDocument.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .purchasePresentation()
                .updateAvailableAlert()
                .appLockOverlay()
        }
        .modelContainer(sharedModelContainer)
    }
}
