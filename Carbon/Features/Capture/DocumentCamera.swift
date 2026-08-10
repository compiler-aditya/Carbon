import CoreGraphics
import SwiftUI
import UIKit
import VisionKit

/// The system document scanner, wrapped for SwiftUI.
///
/// `VNDocumentCameraViewController` is a view controller, which is the one place the project
/// accepts UIKit. It is worth it: edge detection, perspective correction, shadow handling and
/// multi-page capture for free, in a UI people already know from Notes and Files. Building
/// our own camera would take a day and be worse.
struct DocumentCamera: UIViewControllerRepresentable {
    /// Called with every captured page, in order. The caller persists them **before** any
    /// processing begins — a crash mid-extraction must never lose someone's photograph.
    let onFinish: ([CGImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: ([CGImage]) -> Void
        private let onCancel: () -> Void

        init(onFinish: @escaping ([CGImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Pull the CGImages out here and hand on nothing UIKit-shaped, so everything
            // downstream stays testable without a camera.
            let pages = (0..<scan.pageCount).compactMap { index in
                scan.imageOfPage(at: index).cgImage
            }
            onFinish(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: any Error
        ) {
            // A failed scan and a cancelled scan are the same thing to the user: they are back
            // where they started with nothing captured. No dialog for it.
            onCancel()
        }
    }

    /// Whether the scanner can run at all. False on a simulator, which is very likely where
    /// this app is first opened by someone who did not build it — the photo-library path and
    /// the bundled sample forms exist for exactly that case.
    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }
}
