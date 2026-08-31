import PhotosUI
import SwiftData
import SwiftUI

struct DocumentDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var document: VaultDocument

    @State private var pagePreviewItem: DocumentPagePreviewItem?
    @State private var showingEditSheet = false
    @State private var showingScanner = false
    @State private var showingPhotosPicker = false
    @State private var showingFileImporter = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var importErrorMessage: String? = nil
    @State private var showingImportError = false
    @State private var documentToExport: VaultDocument? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(document.privacyCategory)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DocumentAppearance.privacyColor(document.privacyCategory).opacity(0.1))
                                .foregroundColor(DocumentAppearance.privacyColor(document.privacyCategory))
                                .cornerRadius(12)

                            Text(DocumentAppearance.displayTag(document.tag))
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DocumentAppearance.tagColor(document.tag).opacity(0.1))
                                .foregroundColor(DocumentAppearance.tagColor(document.tag))
                                .cornerRadius(12)

                            Spacer()

                            Text(document.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(document.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        if let issuer = document.issuer, !issuer.isEmpty {
                            HStack {
                                Image(systemName: "building.columns")
                                    .foregroundColor(.secondary)
                                Text("Issuer: ")
                                    .fontWeight(.medium)
                                Text(issuer)
                            }
                        }
                        if let notes = document.notes, !notes.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "note.text")
                                    .foregroundColor(.secondary)
                                Text(notes)
                            }
                        }
                    }
                    .font(.subheadline)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Pages (\(document.photosData.count))")
                                .font(.headline)
                            Spacer()
                            Menu {
                                Button {
                                    showingScanner = true
                                } label: {
                                    Label("Scan Pages", systemImage: "doc.viewfinder")
                                }
                                Button {
                                    showingPhotosPicker = true
                                } label: {
                                    Label("Add from Photos", systemImage: "photo.on.rectangle")
                                }
                                Button {
                                    showingFileImporter = true
                                } label: {
                                    Label("Add from Files", systemImage: "folder")
                                }
                            } label: {
                                Label("Add Pages", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.vaultAccent)
                            }
                        }

                        if document.photosData.isEmpty {
                            Text("No pages yet. Use Add Pages to attach scans, photos, or files.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        } else {
                            documentPageThumbnails
                        }
                    }
                }
                .padding()
            }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        documentToExport = document
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(document.photosData.isEmpty)
                    .accessibilityLabel("Export PDF")

                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }

                    Button(role: .destructive, action: deleteDocument) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            DocumentMetadataSheet(
                pageCount: document.photosData.count,
                initialTitle: document.title,
                initialTag: document.tag,
                initialPrivacy: document.privacyCategory,
                onSave: { title, privacy, tag in
                    document.title = title
                    document.privacyCategory = privacy
                    document.tag = tag
                    try? modelContext.save()
                    showingEditSheet = false
                },
                onCancel: {
                    showingEditSheet = false
                }
            )
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView { result in
                switch result {
                case .success(let images):
                    appendPages(from: images)
                case .failure(let error):
                    presentImportError(error.localizedDescription)
                }
            }
        }
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 20,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    selectedPhotoItems = []
                    if images.isEmpty {
                        presentImportError("Could not load the selected photos.")
                    } else {
                        appendPages(from: images)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: FileImportService.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Failed", isPresented: $showingImportError, presenting: importErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .documentPDFExport(document: $documentToExport)
        .fullScreenCover(item: $pagePreviewItem) { item in
            DocumentPageFullScreenView(cacheKey: item.id, data: item.data)
        }
    }

    private var documentPageThumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(document.photosData.enumerated()), id: \.offset) { index, data in
                    DocumentPageThumbnailView(
                        cacheKey: "\(document.id.uuidString)-thumb-\(index)",
                        data: data
                    )
                    .frame(width: 100, height: 140)
                    .cornerRadius(8)
                    .clipped()
                    .onTapGesture {
                        pagePreviewItem = DocumentPagePreviewItem(
                            id: "\(document.id.uuidString)-full-\(index)",
                            data: data
                        )
                    }
                }
            }
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
                        appendPages(from: images)
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
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

    private func appendPages(from images: [UIImage]) {
        let pages = DocumentImageEncoder.jpegPages(from: images)
        guard !pages.isEmpty else {
            presentImportError("No pages were found to add.")
            return
        }
        document.photosData.append(contentsOf: pages)
        try? modelContext.save()
    }

    private func presentImportError(_ message: String) {
        importErrorMessage = message
        showingImportError = true
    }

    private func deleteDocument() {
        modelContext.delete(document)
        dismiss()
    }
}
