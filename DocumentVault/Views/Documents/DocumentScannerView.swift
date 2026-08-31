import SwiftUI
@preconcurrency import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var onCompletion: (Result<[UIImage], any Error>) -> Void

    @MainActor
    class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            parent.onCompletion(.success(images))
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            parent.onCompletion(.failure(error))
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
}
