import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    @Binding var selectedProfile: Profile?
    @Binding var selectedTab: Int

    @State private var showingProfileSheet = false
    @State private var showingScanner = false
    @State private var pendingPhotosData: [Data] = []
    @State private var showingMetadataSheet = false
    @State private var openAddProfileOnAppear = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !purchaseManager.isPremiumUnlocked {
                            HomeProBannerView(accentColor: Color.vaultAccent) {
                                purchaseManager.showPaywallSheet()
                            }
                            .padding(.horizontal)
                        }

                        if let profile = selectedProfile {
                            ProfileHeaderCard(profile: profile)
                        } else {
                            NoProfileCard()
                        }

                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            QuickActionBtn(
                                title: "Scan Document",
                                subtitle: "IDs, passports & papers",
                                iconName: "doc.viewfinder.fill",
                                color: .blue
                            ) {
                                showingScanner = true
                            }

                            QuickActionBtn(
                                title: "Documents",
                                subtitle: "Local & private files",
                                iconName: "folder.fill",
                                color: .indigo
                            ) {
                                selectedTab = 1
                            }

                            QuickActionBtn(
                                title: "Family",
                                subtitle: "Switch member",
                                iconName: "person.2.fill",
                                color: .green
                            ) {
                                showingProfileSheet = true
                            }

                            QuickActionBtn(
                                title: "Settings",
                                subtitle: "Tags, lock & privacy",
                                iconName: "gearshape.fill",
                                color: .orange
                            ) {
                                selectedTab = 2
                            }
                        }
                        .padding(.horizontal)

                        if let profile = selectedProfile {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Vault Snapshot")
                                        .font(.headline)
                                    Spacer()
                                    Button("Details") {
                                        selectedTab = 1
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Color.vaultAccent)
                                }
                                .padding(.horizontal)

                                let localCount = profile.documents.filter { $0.privacyCategory == PrivacyCategory.local.rawValue }.count
                                let privateCount = profile.documents.filter { $0.privacyCategory == PrivacyCategory.privateItem.rawValue }.count

                                HStack(spacing: 12) {
                                    MiniMetricCard(
                                        title: "Local",
                                        value: "\(localCount)",
                                        icon: "folder.fill",
                                        color: .blue
                                    )
                                    MiniMetricCard(
                                        title: "Private",
                                        value: "\(privateCount)",
                                        icon: "lock.fill",
                                        color: .purple
                                    )
                                    MiniMetricCard(
                                        title: "Total",
                                        value: "\(profile.documents.count)",
                                        icon: "doc.text.fill",
                                        color: Color.vaultAccent
                                    )
                                }
                                .padding(.horizontal)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Documents")
                                        .font(.headline)
                                    Spacer()
                                    Button("View All") {
                                        selectedTab = 1
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Color.vaultAccent)
                                }
                                .padding(.horizontal)

                                let sortedDocuments = profile.documents.sorted(by: { $0.date > $1.date })
                                if sortedDocuments.isEmpty {
                                    Text("No documents yet. Tap Scan Document to capture a passport, ID, or other paper.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(sortedDocuments.prefix(3)) { document in
                                            NavigationLink(destination: DocumentDetailView(document: document)) {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "doc.text.fill")
                                                        .foregroundColor(Color.vaultAccent)
                                                        .frame(width: 30)

                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(document.title)
                                                            .font(.subheadline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                        Text("\(document.privacyCategory) • \(DocumentAppearance.displayTag(document.tag))")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding()
                                                .background(Color(.systemGray6))
                                                .cornerRadius(10)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle(AppConstants.displayName)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingProfileSheet = true }) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                Text(selectedProfile?.name ?? "Select Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(Color.vaultAccent)
                        }
                    }
                }
                .sheet(isPresented: $showingProfileSheet) {
                    ProfileView(
                        selectedProfile: $selectedProfile,
                        openAddProfileOnAppear: $openAddProfileOnAppear,
                        onUpgradeRequested: requestUpgradeFromProfileSheet
                    )
                }
                .onChange(of: purchaseManager.shouldResumeAddFamilyMember) { _, shouldResume in
                    guard shouldResume else { return }
                    purchaseManager.clearResumeAddFamilyMember()
                    openAddProfileOnAppear = true
                    showingProfileSheet = true
                }
                .sheet(isPresented: $showingScanner) {
                    DocumentScannerView { result in
                        switch result {
                        case .success(let images):
                            presentMetadata(for: images)
                        case .failure(let error):
                            print("Scanner failed: \(error.localizedDescription)")
                        }
                    }
                }
                .sheet(isPresented: $showingMetadataSheet) {
                    DocumentMetadataSheet(
                        pageCount: pendingPhotosData.count,
                        onSave: { title, privacy, tag in
                            savePendingDocument(title: title, privacy: privacy, tag: tag)
                        },
                        onCancel: {
                            pendingPhotosData = []
                            showingMetadataSheet = false
                        }
                    )
                }
            }
        }
    }

    private func requestUpgradeFromProfileSheet() {
        showingProfileSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            purchaseManager.showPaywallSheet(intent: .addFamilyMember)
        }
    }

    private func presentMetadata(for images: [UIImage]) {
        let pages = DocumentImageEncoder.jpegPages(from: images)
        guard !pages.isEmpty else { return }
        pendingPhotosData = pages
        showingMetadataSheet = true
    }

    private func savePendingDocument(title: String, privacy: String, tag: String) {
        guard let profile = selectedProfile else {
            pendingPhotosData = []
            showingMetadataSheet = false
            return
        }

        let document = VaultDocument(
            title: title,
            date: Date(),
            privacyCategory: privacy,
            tag: tag,
            rawOCRText: "",
            photosData: pendingPhotosData,
            isAIProcessed: false
        )
        document.profile = profile
        profile.documents.append(document)
        try? modelContext.save()

        AppReviewManager.recordDocumentSaved()

        pendingPhotosData = []
        showingMetadataSheet = false
    }
}

struct ProfileHeaderCard: View {
    var profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE PROFILE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))

                    Text(profile.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()

                Text(profile.relation)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                    Text("\(profile.documents.count) documents")
                }
                .font(.subheadline)
                .foregroundColor(.white)

                if let notes = profile.notes, !notes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                        Text(notes)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.doksyPrimary, Color(red: 0.91, green: 0.35, blue: 0.18)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.vaultAccent.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct NoProfileCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to \(AppConstants.displayName)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(AppConstants.tagline)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vaultAccent)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct QuickActionBtn: View {
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName)
                        .foregroundColor(color)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct MiniMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .padding(5)
                    .background(color.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
