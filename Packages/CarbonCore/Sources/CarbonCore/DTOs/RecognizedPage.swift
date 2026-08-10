import Foundation

/// One page of a scan, after recognition and after being normalised into our own shapes.
///
/// Nothing downstream of this type imports Vision. That is the point of it: the extraction
/// ladder, the tests and the corpus harness all work on values that can be built by hand,
/// serialised to JSON, and replayed without a camera or a framework.
public struct RecognizedPage: Sendable, Codable, Hashable {
    public let pageID: UUID
    public let blocks: [RecognizedBlock]
    public let tables: [RecognizedTable]
    public let detectedData: [DetectedDatum]

    /// Reading-order concatenation of the page. This is what Tier 2 is given — the text of
    /// the page and nothing else. The image never crosses this boundary.
    public let fullText: String

    public init(
        pageID: UUID,
        blocks: [RecognizedBlock],
        tables: [RecognizedTable],
        detectedData: [DetectedDatum],
        fullText: String
    ) {
        self.pageID = pageID
        self.blocks = blocks
        self.tables = tables
        self.detectedData = detectedData
        self.fullText = fullText
    }

    /// The table a table-mode template should be read from: the largest one on the page by
    /// area. A register photographed at an angle often yields one real grid plus fragments,
    /// and the real grid is reliably the biggest.
    public var primaryTable: RecognizedTable? {
        tables.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }
}
