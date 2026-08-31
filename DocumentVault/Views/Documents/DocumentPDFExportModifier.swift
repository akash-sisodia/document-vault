import SwiftUI

/// Shared export flow: optional password sheet, progress, share sheet, and errors.
struct DocumentPDFExportModifier: ViewModifier {
    @Binding var document: VaultDocument?

    @State private var showingExportSheet = false
    @State private var showingExportShare = false
    @State private var exportURL: URL?
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var exportErrorMessage: String?
    @State private var showingExportError = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text(processingMessage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let document {
                    ExportPDFSheet(
                        documentTitle: document.title,
                        onExport: { password in
                            showingExportSheet = false
                            performExport(document: document, password: password)
                        },
                        onCancel: {
                            showingExportSheet = false
                            self.document = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showingExportShare, onDismiss: { document = nil }) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
            .alert("Export Failed", isPresented: $showingExportError, presenting: exportErrorMessage) { _ in
                Button("OK", role: .cancel) {
                    document = nil
                }
            } message: { message in
                Text(message)
            }
            .onChange(of: document) { _, newValue in
                if newValue != nil {
                    showingExportSheet = true
                }
            }
    }

    private func performExport(document: VaultDocument, password: String?) {
        isProcessing = true
        processingMessage = "Exporting PDF..."
        Task {
            do {
                let url = try PDFExporter.exportDocument(document, password: password)
                await MainActor.run {
                    isProcessing = false
                    exportURL = url
                    showingExportShare = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    exportErrorMessage = error.localizedDescription
                    showingExportError = true
                }
            }
        }
    }
}

extension View {
    func documentPDFExport(document: Binding<VaultDocument?>) -> some View {
        modifier(DocumentPDFExportModifier(document: document))
    }
}
