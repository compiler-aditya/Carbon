import Foundation
import Testing

@testable import CarbonCore

/// The assist that turns a scanned register into a template in one tap.
///
/// The rule under test throughout: **the body decides the type, the header only breaks ties.**
/// A column called "Amount" holding words is text, and a column called "Reference" holding
/// money is money.
@Suite("Detecting columns from a scanned form")
struct ColumnDetectorTests {
    private func cell(_ text: String, column: Int, row: Int, span: Int = 1) -> RecognizedCell {
        RecognizedCell(
            text: text,
            frame: NormalizedRect(x: 0.1 * Double(column), y: 0.1 * Double(row), width: 0.09, height: 0.05),
            rowRange: row...row,
            columnRange: column...(column + span - 1),
            recognitionConfidence: 0.95
        )
    }

    private func page(header: [String], rows: [[String]]) -> RecognizedPage {
        var grid: [[RecognizedCell]] = [
            header.enumerated().map { cell($0.element, column: $0.offset, row: 0) }
        ]
        for (rowIndex, row) in rows.enumerated() {
            grid.append(row.enumerated().map { cell($0.element, column: $0.offset, row: rowIndex + 1) })
        }
        return RecognizedPage(
            pageID: UUID(),
            blocks: [],
            tables: [
                RecognizedTable(
                    frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    rows: grid,
                    headerRowIndex: 0
                )
            ],
            detectedData: [],
            fullText: ""
        )
    }

    @Test("A register becomes the five fields it prints, with types read off its own rows")
    func detectsTheSampleRegister() {
        let detected = ColumnDetector.columns(
            in: page(
                header: ["Date", "Item", "Qty", "Rate", "Amount"],
                rows: [
                    ["01/04/2026", "Basmati rice 5kg", "12", "560.00", "6720.00"],
                    ["01/04/2026", "Mustard oil 1L", "8", "185.50", "1484.00"],
                    ["02/04/2026", "Turmeric powder", "24", "42.00", "1008.00"],
                ]
            )
        )

        #expect(detected.map(\.label) == ["Date", "Item", "Qty", "Rate", "Amount"])
        #expect(detected.map(\.type) == [.date, .text, .integer, .currency, .currency])
    }

    @Test("The values win over the heading when the two disagree")
    func bodyBeatsHeader() {
        // "Amount" is a perfectly ordinary name for a column of words.
        let detected = ColumnDetector.columns(
            in: page(header: ["Amount"], rows: [["pending"], ["pending"], ["waived"]])
        )
        #expect(detected.first?.type == .text)
    }

    @Test("A money column with no symbol on any row is still money")
    func moneyWithoutSymbols() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Rate"], rows: [["560.00"], ["185.50"], ["42.00"]])
        )
        #expect(detected.first?.type == .currency)
    }

    @Test("A symbol on the rows makes it money whatever the heading says")
    func symbolsAreEnough() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Col 3"], rows: [["₹560"], ["₹185"], ["₹42"]])
        )
        #expect(detected.first?.type == .currency)
    }

    /// The threshold exists for exactly this: scanning is imperfect, and one bad cell in a
    /// column of five must not demote the other four.
    @Test("One misread cell does not change the column's type")
    func toleratesAMisread() {
        let detected = ColumnDetector.columns(
            in: page(
                header: ["Qty"],
                rows: [["12"], ["8"], ["24"], ["l6"], ["30"]]
            )
        )
        #expect(detected.first?.type == .integer)
    }

    @Test("Enough disagreement does change it")
    func enoughNoiseIsNotAColumnOfNumbers() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Qty"], rows: [["12"], ["n/a"], ["see note"], ["pending"]])
        )
        #expect(detected.first?.type == .text)
    }

    @Test("A blank gutter column is not a field")
    func skipsTheRowNumberGutter() {
        let detected = ColumnDetector.columns(
            in: page(header: ["", "Item"], rows: [["1", "Sugar"], ["2", "Tea"]])
        )
        #expect(detected.map(\.label) == ["Item"])
    }

    /// A heading merged across two columns names neither of them. Inventing a field from it
    /// would put a wrong label on the template that the user then has to notice and undo.
    @Test("A heading spanning two columns is left for the user")
    func skipsSpanningHeaders() {
        var grid: [[RecognizedCell]] = [[
            cell("Date", column: 0, row: 0),
            cell("Amount in words and figures", column: 1, row: 0, span: 2),
        ]]
        grid.append([
            cell("01/04/2026", column: 0, row: 1),
            cell("six thousand", column: 1, row: 1),
            cell("6000", column: 2, row: 1),
        ])
        let scanned = RecognizedPage(
            pageID: UUID(), blocks: [],
            tables: [
                RecognizedTable(
                    frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    rows: grid, headerRowIndex: 0
                )
            ],
            detectedData: [], fullText: ""
        )

        #expect(ColumnDetector.columns(in: scanned).map(\.label) == ["Date"])
    }

    @Test("A blank form has headers and nothing under them, so the heading decides alone")
    func blankFormFallsBackToTheHeading() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Date", "Particulars", "Qty", "Amount"], rows: [])
        )
        #expect(detected.map(\.type) == [.date, .text, .integer, .currency])
    }

    /// Scanning a *blank* form is the flow the video demos, so it must not come back empty.
    @Test("A blank form still produces every field")
    func blankFormProducesFields() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Date", "Item", "Qty"], rows: [])
        )
        #expect(detected.count == 3)
    }

    @Test("The header's own spelling is kept as an alias, so next week it matches exactly")
    func keepsTheSpellingAsAnAlias() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Amt."], rows: [["6720.00"]])
        )
        #expect(detected.first?.alias == "amt.")
        #expect(detected.first?.label == "Amt.")
    }

    @Test("Whitespace is collapsed and trailing punctuation dropped, but wording is never changed")
    func tidiesWithoutRewording() {
        #expect(ColumnDetector.tidy("  Qty \n per  unit ") == "Qty per unit")
        #expect(ColumnDetector.tidy("Amount:") == "Amount")
        // Not "Quantity". The label on the template is the label on the paper.
        #expect(ColumnDetector.tidy("QTY.") == "QTY.")
    }

    @Test("A page with no table at all yields nothing rather than failing")
    func noTableNoColumns() {
        let empty = RecognizedPage(
            pageID: UUID(), blocks: [], tables: [], detectedData: [], fullText: "nothing here"
        )
        #expect(ColumnDetector.columns(in: empty).isEmpty)
    }

    @Test("A phone column is typed from its heading plus the shape of its digits")
    func detectsPhone() {
        let detected = ColumnDetector.columns(
            in: page(header: ["Mobile"], rows: [["9876543210"], ["9812345678"]])
        )
        #expect(detected.first?.type == .phone)
    }

    /// "no" means a count; "notes" does not. A substring rule would type the Notes column on
    /// every register as a number.
    @Test("Header hints match whole words, not substrings")
    func hintsAreWholeWords() {
        #expect(ColumnDetector.suggestsCount("No"))
        #expect(!ColumnDetector.suggestsCount("Notes"))
        #expect(ColumnDetector.suggestsCurrency("Total amount"))
        #expect(!ColumnDetector.suggestsCurrency("Ratepayer name"))
    }
}
