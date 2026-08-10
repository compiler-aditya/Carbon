/// Lifecycle of one captured record.
///
/// Raw values are persisted. Never rename a case; only add.
public enum RecordStatus: String, Codable, Sendable, CaseIterable {
    /// Mid-capture, not yet committed.
    case draft

    /// At least one value is below `ConfidenceThreshold.reviewRequired`, or unresolved.
    case needsReview

    /// The user has reviewed it, or every value was high-confidence.
    case confirmed
}
