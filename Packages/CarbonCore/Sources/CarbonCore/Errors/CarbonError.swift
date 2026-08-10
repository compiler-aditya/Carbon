/// Everything that can go wrong, exhaustively, in one type.
///
/// No `NSError` reaches the UI and no error string is built at a call site — each case owns
/// its copy, in `CarbonError+Copy.swift`.
///
/// **Meter limits are deliberately absent.** Reaching the free-tier template or record limit
/// is a normal outcome of using the app, not a failure. Limits are a `MeterDecision` and they
/// route to the paywall. Modelling them here is how a paywall ends up presented as an alert.
public enum CarbonError: Error, Equatable, Hashable, Sendable {
    case cameraUnavailable
    case cameraPermissionDenied
    case pageWriteFailed(underlying: String)
    case recognitionFailed(pageIndex: Int)

    /// A table-mode template met a page with no table on it.
    case noTableFound

    /// Nothing on the page matched the template. Usually means the wrong template, not a bad scan.
    case noFieldsMatched

    case modelUnavailable(reason: ModelUnavailableReason)
    case modelTimedOut
    case exportFailed(underlying: String)

    /// Whether this should be put in front of the user at all.
    ///
    /// The model being unavailable or slow is not the user's problem to solve: extraction has
    /// already carried on down the ladder and produced a usable result. These surface as a
    /// single line in Settings, never as an alert interrupting a scan.
    public var isUserFacing: Bool {
        switch self {
        case .modelUnavailable, .modelTimedOut: false
        default: true
        }
    }
}
