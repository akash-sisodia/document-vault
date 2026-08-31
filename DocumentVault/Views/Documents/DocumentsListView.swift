import PhotosUI
import SwiftData
import SwiftUI

struct DocumentsListView: View {
    @Environment(\.modelContext) private var modelContext
    var selectedProfile: Profile?

    @ObservedObject private var tagStore = DocumentTagStore.shared

    @State private var searchText = ""
    @State private var selectedPrivacy = "All"
    @State private var selectedTag = "All"
    @State private var showingScanner = false
    @State private var showingPhotosPicker = false
    @State private var showingFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    @State private var pendingPhotosData: [Data] = []
    @State private var showingMetadataSheet = false

    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var importErrorMessage: String? = nil
    @State private var showingImportError = false
    @State private var documentToExport: VaultDocument? = nil

    private let privacyChips = ["All"] + PrivacyCategory.allCases.map(\.rawValue)

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    chipRow(privacyChips, selection: $selectedPrivacy)
                    chipRow(tagStore.filterChips, selection: $selectedTag)

                    if let profile = selectedProfile {
                        let filteredDocuments = filterDocuments(profile.documents)

                        if filteredDocuments.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text("No Documents Found")
                                    .font(.headline)
                                Text("Scan or import a passport, ID, or other family document to get started.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)

                                Button(action: { showingScanner = true }) {
                                    HStack {
                                        Image(systemName: "doc.viewfinder")
                                        Text("Scan Document")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.vaultAccent)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 60)
                                .padding(.top, 10)
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(filteredDocuments) { document in
                                    NavigationLink(destination: DocumentDetailView(document: document)) {
                                        HStack(spacing: 15) {
                                            ZStack {
                                                Circle()
                                                    .fill(DocumentAppearance.tagColor(document.tag).opacity(0.1))
                                                    .frame(width: 44, height: 44)

                                                Image(systemName: "doc.text.fill")
                                                    .foregroundColor(DocumentAppearance.tagColor(document.tag))
                                                    .font(.title3)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(document.title)
                                                    .font(.headline)
                                                    .lineLimit(1)

                                                HStack {
                                                    Text(document.privacyCategory)
                                                        .font(.caption)
                                                        .foregroundColor(DocumentAppearance.privacyColor(document.privacyCategory))
                                                    Text("•").foregroundColor(.secondary)
                                                    Text(DocumentAppearance.displayTag(document.tag))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Text("•").foregroundColor(.secondary)
                                                    Text(document.date, style: .date)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .contextMenu {
                                        if !document.photosData.isEmpty {
                                            Button {
                                                documentToExport = document
                                            } label: {
                                                Label("Export PDF", systemImage: "square.and.arrow.up")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        VStack {
                            Text("Please select or create a profile first.")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .navigationTitle("Documents")
                .searchable(text: $searchText, prompt: "Search documents...")
                .onAppear {
                    if let profile = selectedProfile {
                        tagStore.ensureLegacyTagsVisible(from: profile.documents.map(\.tag))
                    }
                    if selectedTag != "All", !tagStore.tags.contains(selectedTag) {
                        selectedTag = "All"
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { showingScanner = true }) {
                                Label("Scan Document", systemImage: "doc.viewfinder")
                            }
                            Button(action: { showingPhotosPicker = true }) {
                                Label("Import from Photos", systemImage: "photo.on.rectangle")
                            }
                            Button(action: { showingFileImporter = true }) {
                                Label("Import from Files", systemImage: "folder")
                            }
                        } label: {
                            DoksyGlassAddButton()
                        }
                    }
                }
                .sheet(isPresented: $showingScanner) {
                    DocumentScannerView { result in
                        switch result {
                        case .success(let images):
                            presentMetadata(for: images)
                        case .failure(let error):
                            presentImportError(error.localizedDescription)
                        }
                    }
                }
                .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotoItem, matching: .images)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let item = newItem,
                           let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            presentMetadata(for: [image])
                        }
                        selectedPhotoItem = nil
                    }
                }
                .fileImporter(
                    isPresented: $showingFileImporter,
                    allowedContentTypes: FileImportService.allowedContentTypes,
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
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
                .alert("Import Failed", isPresented: $showingImportError, presenting: importErrorMessage) { _ in
                    Button("OK", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
                .documentPDFExport(document: $documentToExport)

                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 15) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text(processingMessage)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(30)
                        .background(Color.secondary.opacity(0.8))
                        .cornerRadius(16)
                        .shadow(radius: 10)
                        .padding(.horizontal, 40)
                    }
                }
            }
        }
    }

    private func chipRow(_ chips: [String], selection: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selection.wrappedValue == chip ? Color.vaultAccent : Color(.systemGray6))
                        .foregroundColor(selection.wrappedValue == chip ? .white : .primary)
                        .cornerRadius(20)
                        .onTapGesture {
                            selection.wrappedValue = chip
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            isProcessing = true
            processingMessage = "Loading file..."

            Task.detached(priority: .userInitiated) {
                do {
                    let images = try FileImportService.loadImages(from: url)
                    await MainActor.run {
                        isProcessing = false
                        presentMetadata(for: images)
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        processingMessage = ""
                        presentImportError(error.localizedDescription)
                    }
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return
            }
            presentImportError(error.localizedDescription)
        }
    }

    private func presentMetadata(for images: [UIImage]) {
        let pages = DocumentImageEncoder.jpegPages(from: images)
        guard !pages.isEmpty else {
            presentImportError("No pages were found in the selected file.")
            return
        }
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

    private func presentImportError(_ message: String) {
        importErrorMessage = message
        showingImportError = true
    }

    private func filterDocuments(_ documents: [VaultDocument]) -> [VaultDocument] {
        var list = documents

        if selectedPrivacy != "All" {
            list = list.filter { $0.privacyCategory == selectedPrivacy }
        }

        if selectedTag != "All" {
            list = list.filter { $0.tag == selectedTag }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(query) ||
                $0.tag.lowercased().contains(query) ||
                $0.privacyCategory.lowercased().contains(query) ||
                ($0.issuer?.lowercased().contains(query) ?? false) ||
                ($0.notes?.lowercased().contains(query) ?? false)
            }
        }

        return list.sorted(by: { $0.date > $1.date })
    }
}
