/// What the user can actually do about an error.
///
/// Copy that says what to do and a screen that offers no way to do it is worse than either
/// alone, so the affordance is derived from the same exhaustive switch as the sentence. A new
/// error case cannot ship with guidance but no button.
public enum ErrorRecovery: Equatable, Sendable {
    /// Send them to the Settings app. Only for a permission the app cannot grant itself.
    case openSettings

    /// Offer the failed thing again. The caller decides what "again" means for its screen.
    case retry

    /// Nothing to do but read it and carry on. The way out is the screen behind.
    case acknowledge
}

extension CarbonError {
    public var recovery: ErrorRecovery {
        switch self {
        case .cameraPermissionDenied:
            .openSettings

        // Retrying the camera is pointless when the device has none; the guidance already
        // points at the photo library, which is one tap away on the screen behind.
        case .cameraUnavailable:
            .acknowledge

        case .pageWriteFailed, .recognitionFailed, .imageUnreadable,
            .noTableFound, .noFieldsMatched, .saveFailed, .exportFailed:
            .retry

        // Never shown, so the affordance is moot — but the switch stays exhaustive so adding
        // a case forces a decision here too.
        case .modelUnavailable, .modelTimedOut:
            .acknowledge
        }
    }
}
