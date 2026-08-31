import SwiftUI

struct DocumentMetadataSheet: View {
    let pageCount: Int
    let initialTitle: String
    let initialTag: String
    let initialPrivacy: String
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void

    @ObservedObject private var tagStore = DocumentTagStore.shared
    @State private var title: String
    @State private var selectedTag: String
    @State private var selectedPrivacy: String
    @FocusState private var titleFocused: Bool

    init(
        pageCount: Int,
        initialTitle: String = "",
        initialTag: String = "",
        initialPrivacy: String = PrivacyCategory.local.rawValue,
        onSave: @escaping (String, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.pageCount = pageCount
        self.initialTitle = initialTitle
        self.initialTag = initialTag
        self.initialPrivacy = initialPrivacy
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initialTitle)
        _selectedTag = State(initialValue: initialTag)
        _selectedPrivacy = State(initialValue: initialPrivacy.isEmpty ? PrivacyCategory.local.rawValue : initialPrivacy)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Document name", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)

                    Text("\(pageCount) page\(pageCount == 1 ? "" : "s") ready to save")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Document")
                }

                Section {
                    Picker("Category", selection: $selectedPrivacy) {
                        ForEach(PrivacyCategory.allCases) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Category")
                } footer: {
                    Text("Local is everyday paperwork. Private is for sensitive IDs such as passports. Both stay on this device.")
                }

                Section {
                    Picker("Tag", selection: $selectedTag) {
                        Text("None").tag("")
                        ForEach(tagStore.tags, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }
                } header: {
                    Text("Tag")
                } footer: {
                    Text("Tags help you organize and filter documents. Manage them in Settings.")
                }
            }
            .navigationTitle(initialTitle.isEmpty ? "New Document" : "Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            selectedPrivacy,
                            selectedTag
                        )
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if title.isEmpty {
                    title = Self.defaultTitle()
                }
                if !initialTag.isEmpty,
                   !tagStore.tags.contains(where: { $0.caseInsensitiveCompare(initialTag) == .orderedSame }) {
                    _ = tagStore.addTag(initialTag)
                    selectedTag = initialTag
                }
                titleFocused = true
            }
        }
    }

    static func defaultTitle(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Document (\(formatter.string(from: date)))"
    }
}

enum DocumentImageEncoder {
    static func jpegPages(from images: [UIImage], quality: CGFloat = 0.7) -> [Data] {
        images.compactMap { $0.jpegData(compressionQuality: quality) }
    }
}
