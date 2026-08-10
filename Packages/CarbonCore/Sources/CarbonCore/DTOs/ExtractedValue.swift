import Foundation

/// One field's worth of extraction output, before it reaches the store.
///
/// Every tier of the ladder produces this same shape, which is what lets Tier 1, Tier 2 and
/// Tier 3 be swapped and compared without anything downstream noticing.
public struct ExtractedValue: Sendable, Hashable {
    public let fieldKey: String
    public let rawText: String
    public let normalized: String
    public let confidence: Double
    public let source: ExtractionSource
    public let frame: NormalizedRect?

    public init(
        fieldKey: String,
        rawText: String,
        normalized: String,
        confidence: Double,
        source: ExtractionSource,
        frame: NormalizedRect?
    ) {
        self.fieldKey = fieldKey
        self.rawText = rawText
        self.normalized = normalized
        self.confidence = confidence
        self.source = source
        self.frame = frame
    }

    /// Nothing was found for this field. A normal outcome — it renders as an empty field
    /// on a dotted rule and sorts to the top of review.
    public static func unresolved(fieldKey: String) -> ExtractedValue {
        ExtractedValue(
            fieldKey: fieldKey,
            rawText: "",
            normalized: "",
            confidence: 0,
            source: .unresolved,
            frame: nil
        )
    }

    public var band: ConfidenceBand {
        ConfidenceBand(confidence: confidence, source: source)
    }
}
