import SwiftData
import SwiftUI

struct DocumentTagsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    @ObservedObject private var tagStore = DocumentTagStore.shared

    @State private var newTagName = ""
    @State private var tagBeingRenamed: String?
    @State private var renameText = ""
    @State private var showingRenameAlert = false
    @State private var showingDuplicateAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New tag name", text: $newTagName)
                        .textInputAutocapitalization(.words)
                        .onSubmit(addTag)

                    Button("Add", action: addTag)
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } footer: {
                Text("Each document can have one tag. Renaming a tag updates every document that uses it.")
            }

            Section("Your Tags") {
                if tagStore.tags.isEmpty {
                    Text("No tags yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tagStore.tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button {
                                tagBeingRenamed = tag
                                renameText = tag
                                showingRenameAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
            }
        }
        .navigationTitle("Document Tags")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Tag", isPresented: $showingRenameAlert) {
            TextField("Tag name", text: $renameText)
            Button("Cancel", role: .cancel) {
                tagBeingRenamed = nil
            }
            Button("Save") {
                renameSelectedTag()
            }
        } message: {
            Text("Documents using this tag will be updated.")
        }
        .alert("Could Not Save Tag", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if tagStore.addTag(name) {
            newTagName = ""
        } else {
            alertMessage = "A tag with that name already exists."
            showingDuplicateAlert = true
        }
    }

    private func renameSelectedTag() {
        guard let oldName = tagBeingRenamed else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }

        if tagStore.renameTag(from: oldName, to: newName) {
            for profile in profiles {
                for document in profile.documents where document.tag == oldName {
                    document.tag = newName
                }
            }
            try? modelContext.save()
        } else {
            alertMessage = "Could not rename the tag. Choose a unique non-empty name."
            showingDuplicateAlert = true
        }
        tagBeingRenamed = nil
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tagStore.tags[index]
            for profile in profiles {
                for document in profile.documents where document.tag == tag {
                    document.tag = ""
                }
            }
            tagStore.deleteTag(tag)
        }
        try? modelContext.save()
    }
}
