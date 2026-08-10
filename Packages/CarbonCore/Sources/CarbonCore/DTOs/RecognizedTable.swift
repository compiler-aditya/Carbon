/// A grid found on the page. Rows are row-major and may be ragged.
public struct RecognizedTable: Sendable, Codable, Hashable {
    public let frame: NormalizedRect
    public let rows: [[RecognizedCell]]

    /// Our own inference — Vision does not label a header row. Nil when no row looks like one,
    /// which is a normal outcome on a register whose header is printed above the ruled area.
    public let headerRowIndex: Int?

    public init(frame: NormalizedRect, rows: [[RecognizedCell]], headerRowIndex: Int?) {
        self.frame = frame
        self.rows = rows
        self.headerRowIndex = headerRowIndex
    }

    public var headerRow: [RecognizedCell]? {
        guard let headerRowIndex, rows.indices.contains(headerRowIndex) else { return nil }
        return rows[headerRowIndex]
    }

    /// Rows that carry data — everything after the header. When there is no header every row
    /// is a data row, which is the correct reading of a form whose columns were mapped by hand.
    public var dataRows: [[RecognizedCell]] {
        guard let headerRowIndex else { return rows }
        return Array(rows.dropFirst(headerRowIndex + 1))
    }
}
