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

    public init(
        records: [ExtractedRecord],
        pageID: UUID,
        durationMs: Int,
        engineVersion: String,
        diagnostics: [String]
    ) {
        self.records = records
        self.pageID = pageID
        self.durationMs = durationMs
        self.engineVersion = engineVersion
        self.diagnostics = diagnostics
    }

    /// Share of values that Tier 1 resolved without the model. Reported in the README as
    /// evidence that the deterministic path carries most of the load.
    public var deterministicShare: Double {
        let all = records.flatMap(\.values)
        guard !all.isEmpty else { return 0 }
        return Double(all.count { $0.source == .deterministic }) / Double(all.count)
    }
}
