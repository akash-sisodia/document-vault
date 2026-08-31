import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Profile.name) private var profiles: [Profile]
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    @Binding var selectedProfile: Profile?
    @Binding var openAddProfileOnAppear: Bool

    var onUpgradeRequested: () -> Void

    @State private var showingAddProfile = false
    @State private var name = ""
    @State private var relation = "Self"
    @State private var notes = ""
    @State private var dateOfBirth = Date()
    @State private var isDobSelected = false

    let relations = ["Self", "Spouse", "Child", "Parent", "Grandparent", "Other"]

    init(
        selectedProfile: Binding<Profile?>,
        openAddProfileOnAppear: Binding<Bool> = .constant(false),
        onUpgradeRequested: @escaping () -> Void
    ) {
        _selectedProfile = selectedProfile
        _openAddProfileOnAppear = openAddProfileOnAppear
        self.onUpgradeRequested = onUpgradeRequested
    }

    private var canAddAnotherProfile: Bool {
        profiles.count < 1 || purchaseManager.isPremiumUnlocked
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Family Members").textCase(.none)) {
                    if profiles.isEmpty {
                        Text("No profiles created yet. Add one using the + button.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(profiles) { profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text(profile.relation)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if profile.id == selectedProfile?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(Color.vaultAccent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProfile = profile
                                UserDefaults.standard.set(profile.id.uuidString, forKey: "SelectedProfileID")
                            }
                        }
                        .onDelete(perform: deleteProfiles)
                    }
                }

                if !purchaseManager.isPremiumUnlocked {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The first profile is free. Unlock Pro to add family members.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(action: onUpgradeRequested) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.vaultAccent, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }
            }
            .navigationTitle("Profiles & Family")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: requestAddProfile) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                presentAddProfileIfRequested()
            }
            .onChange(of: openAddProfileOnAppear) { _, shouldOpen in
                if shouldOpen {
                    presentAddProfileIfRequested()
                }
            }
            .sheet(isPresented: $showingAddProfile) {
                NavigationStack {
                    Form {
                        Section("Personal Details") {
                            TextField("Full Name", text: $name)
                            Picker("Relationship", selection: $relation) {
                                ForEach(relations, id: \.self) { r in
                                    Text(r).tag(r)
                                }
                            }
                            Toggle("Specify Date of Birth", isOn: $isDobSelected)
                            if isDobSelected {
                                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                            }
                        }
                        Section("Notes") {
                            TextField("Optional notes", text: $notes, axis: .vertical)
                        }
                    }
                    .navigationTitle("Add Family Member")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAddProfile = false
                                resetFields()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                guard canAddAnotherProfile else {
                                    showingAddProfile = false
                                    onUpgradeRequested()
                                    return
                                }
                                let newProfile = Profile(
                                    name: name,
                                    relation: relation,
                                    dateOfBirth: isDobSelected ? dateOfBirth : nil,
                                    notes: notes.isEmpty ? nil : notes
                                )
                                modelContext.insert(newProfile)
                                if selectedProfile == nil {
                                    selectedProfile = newProfile
                                    UserDefaults.standard.set(newProfile.id.uuidString, forKey: "SelectedProfileID")
                                }
                                showingAddProfile = false
                                resetFields()
                            }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func requestAddProfile() {
        if canAddAnotherProfile {
            showingAddProfile = true
        } else {
            onUpgradeRequested()
        }
    }

    private func presentAddProfileIfRequested() {
        guard openAddProfileOnAppear, canAddAnotherProfile else { return }
        openAddProfileOnAppear = false
        showingAddProfile = true
    }

    private func deleteProfiles(offsets: IndexSet) {
        for index in offsets {
            let profileToDelete = profiles[index]
            if selectedProfile?.id == profileToDelete.id {
                selectedProfile = profiles.first(where: { $0.id != profileToDelete.id })
                if let next = selectedProfile {
                    UserDefaults.standard.set(next.id.uuidString, forKey: "SelectedProfileID")
                } else {
                    UserDefaults.standard.removeObject(forKey: "SelectedProfileID")
                }
            }
            modelContext.delete(profileToDelete)
        }
    }

    private func resetFields() {
        name = ""
        relation = "Self"
        notes = ""
        isDobSelected = false
        dateOfBirth = Date()
    }
}
