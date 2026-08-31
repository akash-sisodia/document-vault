import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Profile.name) private var profiles: [Profile]

    @State private var selectedTab = 0
    @State private var selectedProfile: Profile? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedProfile: $selectedProfile, selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            DocumentsListView(selectedProfile: selectedProfile)
                .tabItem {
                    Label("Documents", systemImage: "doc.text.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(Color.vaultAccent)
        .task { await InAppUpdateManager.shared.checkForUpdates() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await InAppUpdateManager.shared.checkForUpdates() }
        }
        .onAppear {
            initializeProfile()
        }
    }

    private func initializeProfile() {
        if profiles.isEmpty {
            let defaultProfile = Profile(name: "My Profile", relation: "Self")
            modelContext.insert(defaultProfile)
            try? modelContext.save()
            selectedProfile = defaultProfile
        } else if let savedIDString = UserDefaults.standard.string(forKey: "SelectedProfileID"),
                  let uuid = UUID(uuidString: savedIDString),
                  let savedProfile = profiles.first(where: { $0.id == uuid }) {
            selectedProfile = savedProfile
        } else {
            selectedProfile = profiles.first
        }
    }
}
