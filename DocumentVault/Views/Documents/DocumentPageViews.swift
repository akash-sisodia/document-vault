import SwiftUI

struct DocumentPagePreviewItem: Identifiable, Equatable {
    let id: String
    let data: Data
}

struct DocumentPageThumbnailView: View {
    let cacheKey: String
    let data: Data
    var maxPixelSize: CGFloat = 280

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task(id: cacheKey) {
            image = await DocumentImageCache.shared.thumbnail(
                for: cacheKey,
                data: data,
                maxPixelSize: maxPixelSize
            )
        }
    }
}

struct DocumentPageFullScreenView: View {
    let cacheKey: String
    let data: Data

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding()
        }
        .task(id: cacheKey) {
            isLoading = true
            image = await DocumentImageCache.shared.fullImage(for: cacheKey, data: data)
            isLoading = false
        }
    }
}
