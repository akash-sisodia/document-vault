import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var profiles: [Profile]
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @ObservedObject private var updateManager = InAppUpdateManager.shared
    @ObservedObject private var lockManager = AppLockManager.shared
    @AppStorage("userName") private var userName = ""

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var exportURL: URL? = nil
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                if !purchaseManager.isPremiumUnlocked {
                    Section("Pro") {
                        SettingsPremiumBannerView(accentColor: Color.vaultAccent) {
                            purchaseManager.showPaywallSheet()
                        }
                    }
                }

                Section("Personalization") {
                    TextField("Your Name", text: $userName)
                        .onChange(of: userName) { _, newValue in
                            UserDefaults.standard.set(
                                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                                forKey: "userName"
                            )
                        }

                    NavigationLink {
                        DocumentTagsSettingsView()
                    } label: {
                        Label("Document Tags", systemImage: "tag.fill")
                    }
                }

                Section("Subscription") {
                    Button {
                        purchaseManager.showPaywallSheet()
                    } label: {
                        Label("Plans & Pricing", systemImage: "tag.fill")
                    }
                    Button {
                        purchaseManager.showCustomerCenterSheet()
                    } label: {
                        Label(
                            purchaseManager.isPremiumUnlocked ? "Manage Subscription" : "Restore Purchases",
                            systemImage: "creditcard.fill"
                        )
                    }
                }

                Section("App") {
                    if updateManager.hasUpdateAvailable(),
                       let version = updateManager.availableStoreVersion {
                        SettingsAppUpdateRow(
                            accentColor: Color.vaultAccent,
                            version: version
                        ) {
                            updateManager.performUpdate()
                        }
                    }

                    Button {
                        Task { await updateManager.checkForUpdates(force: true) }
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                    }

                    Button {
                        AppReviewManager.openAppStoreReviewPage()
                    } label: {
                        Label("Rate on App Store", systemImage: "star.fill")
                    }
                }

                Section("Support") {
                    FeedJarFeedbackButton(label: "Send Feedback")

                    Button {
                        openURL(AppConstants.privacyPolicyURL)
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Button {
                        openURL(AppConstants.termsOfUseURL)
                    } label: {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                }

                Section("More") {
                    ShareLink(item: AppConstants.appStoreURL) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                    }
                }

                Section("Privacy & Security") {
                    Toggle(isOn: appLockBinding) {
                        Label("\(lockManager.biometryName) Lock", systemImage: "faceid")
                    }
                    .disabled(!lockManager.canUseBiometrics && !lockManager.isEnabled)

                    if !lockManager.canUseBiometrics && !lockManager.isEnabled {
                        Text("Set up Face ID or a device passcode in iOS Settings to lock \(AppConstants.displayName).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("When this is on, \(AppConstants.displayName) asks for \(lockManager.biometryName) whenever you open the app or return from the background.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Storage Type", systemImage: "internaldrive.fill")
                        Spacer()
                        Text("100% On-Device")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Privacy Standards", systemImage: "shield.fill")
                        Spacer()
                        Text("DPDP Act 2023 Compliant")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Database Statistics") {
                    HStack {
                        Label("Profiles Active", systemImage: "person.2.fill")
                        Spacer()
                        Text("\(profiles.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Documents", systemImage: "doc.text.fill")
                        Spacer()
                        let totalDocuments = profiles.reduce(0) { $0 + $1.documents.count }
                        Text("\(totalDocuments)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Data Management") {
                    Button(action: exportLocalData) {
                        Label("Export Data Backup (JSON)", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive, action: {
                        alertTitle = "Clear All Data"
                        alertMessage = "Are you sure you want to permanently delete all documents and family profiles? This cannot be undone."
                        showingAlert = true
                    }) {
                        Label("Clear Database", systemImage: "trash")
                    }
                }

                Section("About") {
                    HStack {
                        Text(AppConstants.displayName)
                        Spacer()
                        Text("v\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await updateManager.checkForUpdates(force: false) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await updateManager.checkForUpdates(force: false) }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                if alertTitle == "Clear All Data" {
                    Button("Delete All", role: .destructive) {
                        clearAllDatabase()
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }

    private func exportLocalData() {
        var backupList: [[String: Any]] = []
        for profile in profiles {
            var profDict: [String: Any] = [
                "name": profile.name,
                "relation": profile.relation,
                "notes": profile.notes ?? ""
            ]

            var docs: [[String: Any]] = []
            for document in profile.documents {
                docs.append([
                    "title": document.title,
                    "date": document.date.timeIntervalSince1970,
                    "privacyCategory": document.privacyCategory,
                    "tag": document.tag,
                    "issuer": document.issuer ?? "",
                    "notes": document.notes ?? ""
                ])
            }
            profDict["documents"] = docs
            backupList.append(profDict)
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: backupList, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Doksy_Backup.json")
            try data.write(to: tempURL)

            self.exportURL = tempURL
            self.showingShareSheet = true
        } catch {
            alertTitle = "Backup Failed"
            alertMessage = "Could not export database backup: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func clearAllDatabase() {
        for profile in profiles {
            modelContext.delete(profile)
        }
        try? modelContext.save()

        alertTitle = "Data Cleared"
        alertMessage = "All application data has been deleted."
        showingAlert = true
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { lockManager.isEnabled },
            set: { newValue in
                Task {
                    let succeeded = await lockManager.setEnabled(newValue)
                    if !succeeded, let error = lockManager.lastError {
                        alertTitle = "Could Not Enable Lock"
                        alertMessage = error
                        showingAlert = true
                    }
                }
            }
        )
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
