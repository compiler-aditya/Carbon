/// One cell of a recognised table.
///
/// `rowRange` and `columnRange` come straight from Vision and describe merged cells: a cell
/// spanning two columns reports a range of length two. Tier 1 may choose to skip spanned
/// cells, but the information is kept here because discarding it at the boundary is what
/// makes merged cells an unexplainable failure rather than a handled one.
public struct RecognizedCell: Sendable, Codable, Hashable {
    public let text: String
    public let frame: NormalizedRect
    public let rowRange: ClosedRange<Int>
    public let columnRange: ClosedRange<Int>

    /// Derived, not reported. Vision's table cell carries no confidence of its own, so this
    /// is the minimum across the recognised text lines inside the cell — a cell is only as
    /// trustworthy as its worst line.
    public let recognitionConfidence: Double

    public init(
        text: String,
        frame: NormalizedRect,
        rowRange: ClosedRange<Int>,
        columnRange: ClosedRange<Int>,
        recognitionConfidence: Double
    ) {
        self.text = text
        self.frame = frame
        self.rowRange = rowRange
        self.columnRange = columnRange
        self.recognitionConfidence = recognitionConfidence
    }

    /// True when this cell covers more than one row or column.
    public var isSpanning: Bool { rowRange.count > 1 || columnRange.count > 1 }
}
