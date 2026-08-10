import Foundation
import Testing

@testable import CarbonCore

@Suite("Recognition DTOs")
struct RecognizedPageTests {
    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> NormalizedRect {
        NormalizedRect(x: x, y: y, width: w, height: h)
    }

    private func cell(_ text: String, row: Int, column: Int) -> RecognizedCell {
        RecognizedCell(
            text: text,
            frame: rect(0, 0, 0.1, 0.1),
            rowRange: row...row,
            columnRange: column...column,
            recognitionConfidence: 0.9
        )
    }

    @Test("Data rows exclude everything up to and including the header")
    func dataRowsSkipHeader() {
        let table = RecognizedTable(
            frame: rect(0, 0, 1, 1),
            rows: [
                [cell("Date", row: 0, column: 0)],
                [cell("01/04", row: 1, column: 0)],
                [cell("02/04", row: 2, column: 0)],
            ],
            headerRowIndex: 0
        )
        #expect(table.dataRows.count == 2)
        #expect(table.headerRow?.first?.text == "Date")
    }

    @Test("With no header row, every row carries data")
    func noHeaderMeansAllRows() {
        let table = RecognizedTable(
            frame: rect(0, 0, 1, 1),
            rows: [[cell("01/04", row: 0, column: 0)], [cell("02/04", row: 1, column: 0)]],
            headerRowIndex: nil
        )
        #expect(table.dataRows.count == 2)
        #expect(table.headerRow == nil)
    }

    @Test("The primary table is the largest by area, not the first found")
    func primaryTableIsLargest() {
        let fragment = RecognizedTable(frame: rect(0, 0, 0.2, 0.1), rows: [], headerRowIndex: nil)
        let register = RecognizedTable(frame: rect(0, 0.2, 0.9, 0.7), rows: [], headerRowIndex: nil)
        let page = RecognizedPage(
            pageID: UUID(),
            blocks: [],
            tables: [fragment, register],
            detectedData: [],
            fullText: ""
        )
        #expect(page.primaryTable?.frame == register.frame)
    }

    @Test("A page with no tables has no primary table")
    func noTables() {
        let page = RecognizedPage(
            pageID: UUID(), blocks: [], tables: [], detectedData: [], fullText: ""
        )
        #expect(page.primaryTable == nil)
    }

    @Test("A cell spanning two columns is reported as spanning")
    func spanningCell() {
        let merged = RecognizedCell(
            text: "Total",
            frame: rect(0, 0, 0.4, 0.1),
            rowRange: 3...3,
            columnRange: 2...3,
            recognitionConfidence: 0.8
        )
        #expect(merged.isSpanning)
        #expect(!cell("Qty", row: 0, column: 0).isSpanning)
    }

    @Test("Union covers both rectangles")
    func rectUnion() {
        let combined = rect(0.1, 0.1, 0.2, 0.2).union(rect(0.5, 0.4, 0.1, 0.1))
        #expect(combined == rect(0.1, 0.1, 0.5, 0.4))
    }
}
