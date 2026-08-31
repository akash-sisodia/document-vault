import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum FileImportService {
    enum ImportError: LocalizedError {
        case accessDenied
        case unsupportedType
        case unreadable
        case emptyDocument
        case imageDecodeFailed
        case pdfRasterizeFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Could not access the selected file."
            case .unsupportedType:
                return "Unsupported file type. Please choose a PDF or image."
            case .unreadable:
                return "The selected file could not be read."
            case .emptyDocument:
                return "The selected document has no pages."
            case .imageDecodeFailed:
                return "Could not decode the selected image."
            case .pdfRasterizeFailed:
                return "Could not convert the PDF into images."
            }
        }
    }

    static let allowedContentTypes: [UTType] = [.pdf, .image]

    static func loadImages(from url: URL) throws -> [UIImage] {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ImportError.unreadable
        }

        let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey])
        let contentType = resourceValues?.contentType

        if contentType?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            return try rasterizePDF(at: url)
        }

        if contentType?.conforms(to: .image) == true || isLikelyImageExtension(url.pathExtension) {
            return try loadImage(at: url)
        }

        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return [image]
        }

        if let document = PDFDocument(url: url), document.pageCount > 0 {
            return try rasterizePDF(document: document)
        }

        throw ImportError.unsupportedType
    }

    private static func loadImage(at url: URL) throws -> [UIImage] {
        guard let data = try? Data(contentsOf: url) else {
            throw ImportError.unreadable
        }
        guard let image = UIImage(data: data) else {
            throw ImportError.imageDecodeFailed
        }
        return [image]
    }

    private static func rasterizePDF(at url: URL) throws -> [UIImage] {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.unreadable
        }
        return try rasterizePDF(document: document)
    }

    private static func rasterizePDF(document: PDFDocument) throws -> [UIImage] {
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw ImportError.emptyDocument
        }

        var images: [UIImage] = []
        images.reserveCapacity(pageCount)
        let maxPixelSize: CGFloat = 2048

        for index in 0..<pageCount {
            guard let page = document.page(at: index) else {
                throw ImportError.pdfRasterizeFailed
            }

            let pageRect = page.bounds(for: .mediaBox)
            let longestSide = max(pageRect.width, pageRect.height)
            let scale = min(2.0, maxPixelSize / max(longestSide, 1))
            let renderSize = CGSize(
                width: max(pageRect.width * scale, 1),
                height: max(pageRect.height * scale, 1)
            )

            let renderer = UIGraphicsImageRenderer(size: renderSize)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: renderSize))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: renderSize.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }

            images.append(image)
        }

        guard !images.isEmpty else {
            throw ImportError.emptyDocument
        }

        return images
    }

    private static func isLikelyImageExtension(_ ext: String) -> Bool {
        let known = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp"]
        return known.contains(ext.lowercased())
    }
}
