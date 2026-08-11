import AVFoundation
import CarbonCore

/// Whether the scanner can be opened at all, asked before it is.
///
/// `VNDocumentCameraViewController` presented without permission shows a black frame and no
/// explanation, which reads as a broken app rather than a denied permission. Asking first costs
/// one call and turns that into a sentence with a way out.
enum CameraAuthorization {
    /// The reason the camera cannot be opened, or nil when it can.
    ///
    /// `.notDetermined` deliberately returns nil: the system prompt belongs at the moment the
    /// camera opens, where the request explains itself, not behind a pre-emptive dialog of our
    /// own asking the same question twice.
    @MainActor
    static func denial() -> CarbonError? {
        guard DocumentCamera.isAvailable else { return .cameraUnavailable }

        return switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: .cameraPermissionDenied
        default: nil
        }
    }
}
