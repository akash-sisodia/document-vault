import Foundation
import PDFKit
import UIKit

enum PDFExporter {
    enum ExportError: LocalizedError {
        case noPages
        case writeFailed
        case passwordRequired

        var errorDescription: String? {
            switch self {
            case .noPages:
                return "This document has no pages to export."
            case .writeFailed:
                return "Could not write the PDF file."
            case .passwordRequired:
                return "Enter a password to protect this PDF."
            }
        }
    }

    /// Exports scanned pages of a single vault document as a multi-page PDF.
    static func exportDocument(_ document: VaultDocument, password: String? = nil) throws -> URL {
        let pdf = PDFDocument()
        appendPages(of: document, to: pdf)

        guard pdf.pageCount > 0 else {
            throw ExportError.noPages
        }

        let fileName = sanitizedFileName(document.title) + ".pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var options: [PDFDocumentWriteOption: Any] = [:]
        if let password = password?.trimmingCharacters(in: .whitespacesAndNewlines), !password.isEmpty {
            options[.userPasswordOption] = password
            options[.ownerPasswordOption] = password
        }

        let succeeded: Bool
        if options.isEmpty {
            succeeded = pdf.write(to: url)
        } else {
            succeeded = pdf.write(to: url, withOptions: options)
        }

        guard succeeded else {
            throw ExportError.writeFailed
        }
        return url
    }

    private static func appendPages(of document: VaultDocument, to pdf: PDFDocument) {
        for data in document.photosData {
            guard let image = UIImage(data: data) else { continue }
            let pageImage = orientedImage(image)
            guard let page = PDFPage(image: pageImage) else { continue }
            pdf.insert(page, at: pdf.pageCount)
        }
    }

    private static func orientedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func sanitizedFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Document" : cleaned
    }
}
