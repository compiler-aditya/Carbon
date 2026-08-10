import Foundation

/// One record's worth of extraction output. In table mode a page yields many of these,
/// one per data row; in record mode, exactly one.
public struct ExtractedRecord: Sendable, Hashable {
    /// Which table row produced this. Nil in record mode.
    public let sourceRowIndex: Int?

    public let values: [ExtractedValue]

    public init(sourceRowIndex: Int?, values: [ExtractedValue]) {
        self.sourceRowIndex = sourceRowIndex
        self.values = values
    }

    public func value(forKey key: String) -> ExtractedValue? {
        values.first { $0.fieldKey == key }
    }

    /// The status this record should be stored with. A record needs review if any value is
    /// below the threshold or unresolved — the rule lives here so the write path and the UI
    /// cannot come to different conclusions.
    public var resolvedStatus: RecordStatus {
        values.contains { $0.band == .needsReview } ? .needsReview : .confirmed
    }
}
