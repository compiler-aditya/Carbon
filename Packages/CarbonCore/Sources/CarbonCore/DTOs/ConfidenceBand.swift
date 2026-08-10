/// A confidence score reduced to the three bands the interface actually draws.
///
/// The review UI styles its rule from this rather than from a raw `Double`, so the mapping
/// from number to meaning exists exactly once and is testable without a view.
public enum ConfidenceBand: String, Sendable, CaseIterable {
    /// Solid rule. Read cleanly, ignore it.
    case high

    /// Dashed rule. Glance at it.
    case medium

    /// Dotted rule, in `stamp` red. Needs the user, and sorts to the top of the review list.
    case needsReview

    public init(confidence: Double, source: ExtractionSource) {
        // An unresolved field is always in the needs-review band whatever its score claims,
        // because "we found nothing" is not the same statement as "we are 90% sure".
        guard source != .unresolved else {
            self = .needsReview
            return
        }
        switch confidence {
        case ConfidenceThreshold.high...: self = .high
        case ConfidenceThreshold.medium...: self = .medium
        default: self = .needsReview
        }
    }
}
