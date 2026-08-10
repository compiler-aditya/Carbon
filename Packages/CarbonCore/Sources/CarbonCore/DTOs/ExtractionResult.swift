import Foundation

/// Everything one page of extraction produced, plus the provenance that makes the accuracy
/// numbers in the README possible.
public struct ExtractionResult: Sendable, Hashable {
    public let records: [ExtractedRecord]
    public let pageID: UUID
    public let durationMs: Int

    /// Which combination of engines produced this, e.g. "vision-doc-1|fm-text-1|norm-3".
    /// Stored per record so the corpus harness can compare runs across a week of changes.
    public let engineVersion: String

    /// Surfaced in a debug pane, never to users.
    public let diagnostics: [String]

    /// Header spellings this page taught us, by field key.
    ///
    /// Populated when a column was matched by fuzzy comparison rather than exactly — the
    /// header really says "Amt" and the template only knew "Amount". Recording it turns next
    /// week's guess into next week's exact match, with no model involved. This is the whole
    /// of the app's learning, and it costs about twenty lines.
    public let aliasesToLearn: [String: String]

    public init(
        records: [ExtractedRecord],
        pageID: UUID,
        durationMs: Int,
        engineVersion: String,
        diagnostics: [String],
        aliasesToLearn: [String: String] = [:]
    ) {
        self.records = records
        self.pageID = pageID
        self.durationMs = durationMs
        self.engineVersion = engineVersion
        self.diagnostics = diagnostics
        self.aliasesToLearn = aliasesToLearn
    }

    /// Share of values that Tier 1 resolved without the model. Reported in the README as
    /// evidence that the deterministic path carries most of the load.
    public var deterministicShare: Double {
        let all = records.flatMap(\.values)
        guard !all.isEmpty else { return 0 }
        return Double(all.count { $0.source == .deterministic }) / Double(all.count)
    }
}
