import Foundation

/// An immutable projection of one stored `FieldValue`.
public struct FieldValueSnapshot: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let fieldKey: String

    /// Exactly what recognition produced, before normalization and before any correction.
    /// This is the accuracy dataset; nothing in the app is allowed to overwrite it.
    public let rawText: String

    /// Canonical form. Everything the user sees and everything exported reads this.
    public let normalizedValue: String

    public let confidence: Double
    public let source: ExtractionSource
    public let wasEditedByUser: Bool
    public let frame: NormalizedRect?

    public init(
        id: UUID,
        fieldKey: String,
        rawText: String,
        normalizedValue: String,
        confidence: Double,
        source: ExtractionSource,
        wasEditedByUser: Bool,
        frame: NormalizedRect?
    ) {
        self.id = id
        self.fieldKey = fieldKey
        self.rawText = rawText
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.source = source
        self.wasEditedByUser = wasEditedByUser
        self.frame = frame
    }

    public var band: ConfidenceBand {
        ConfidenceBand(confidence: confidence, source: source)
    }

    /// True when the user changed what recognition read. The share of values where this holds
    /// is the correction rate — the headline accuracy number, harvested from ordinary use.
    public var wasCorrected: Bool {
        wasEditedByUser && rawText != normalizedValue
    }
}
