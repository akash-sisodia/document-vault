import ImageIO
import UIKit

enum DocumentImageDecoder {
    static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    static func fullImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }
}

final class DocumentImageCache {
    static let shared = DocumentImageCache()

    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fullImageCache = NSCache<NSString, UIImage>()

    private init() {
        thumbnailCache.countLimit = 120
        fullImageCache.countLimit = 12
    }

    func cachedThumbnail(for key: String) -> UIImage? {
        thumbnailCache.object(forKey: key as NSString)
    }

    func storeThumbnail(_ image: UIImage, for key: String) {
        thumbnailCache.setObject(image, forKey: key as NSString)
    }

    func thumbnail(for key: String, data: Data, maxPixelSize: CGFloat) async -> UIImage? {
        if let cached = cachedThumbnail(for: key) {
            return cached
        }

        let image = await Task.detached(priority: .userInitiated) {
            DocumentImageDecoder.downsampledImage(from: data, maxPixelSize: maxPixelSize)
        }.value

        if let image {
            storeThumbnail(image, for: key)
        }

        return image
    }

    func fullImage(for key: String, data: Data) async -> UIImage? {
        if let cached = fullImageCache.object(forKey: key as NSString) {
            return cached
        }

        let image = await Task.detached(priority: .userInitiated) {
            DocumentImageDecoder.fullImage(from: data)
        }.value

        if let image {
            fullImageCache.setObject(image, forKey: key as NSString)
        }

        return image
    }
}
