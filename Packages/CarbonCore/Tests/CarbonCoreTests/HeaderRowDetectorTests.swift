import CoreGraphics
import Foundation
import Testing

@testable import CarbonCore

@Suite("Header row detection")
struct HeaderRowDetectorTests {
    private func row(_ texts: [String], index: Int) -> [RecognizedCell] {
        texts.enumerated().map { column, text in
            RecognizedCell(
                text: text,
                frame: NormalizedRect(x: 0, y: 0, width: 0.1, height: 0.1),
                rowRange: index...index,
                columnRange: column...column,
                recognitionConfidence: 0.9
            )
        }
    }

    @Test("A text first row above numeric rows is the header")
    func detectsHeader() {
        let rows = [
            row(["Date", "Item", "Qty", "Amount"], index: 0),
            row(["01/04/2026", "Basmati rice 5kg", "12", "6720.00"], index: 1),
        ]
        #expect(HeaderRowDetector.index(in: rows) == 0)
    }

    @Test("A first row containing a number is data, not a header")
    func numericFirstRowIsNotHeader() {
        let rows = [
            row(["01/04/2026", "Basmati rice 5kg", "12", "6720.00"], index: 0),
            row(["02/04/2026", "Sugar 1kg", "30", "1440.00"], index: 1),
        ]
        #expect(HeaderRowDetector.index(in: rows) == nil)
    }

    @Test("A first row with an empty cell is not a header — headers name every column")
    func emptyCellDisqualifies() {
        let rows = [
            row(["Date", "", "Qty"], index: 0),
            row(["01/04/2026", "Sugar", "30"], index: 1),
        ]
        #expect(HeaderRowDetector.index(in: rows) == nil)
    }

    @Test("An all-text table has no header, so every row is data")
    func allTextTableHasNoHeader() {
        let rows = [
            row(["Name", "Notes"], index: 0),
            row(["Priya", "Called back"], index: 1),
        ]
        #expect(HeaderRowDetector.index(in: rows) == nil)
    }

    @Test("A single row is never a header — there would be no data left")
    func singleRow() {
        #expect(HeaderRowDetector.index(in: [row(["Date", "Qty"], index: 0)]) == nil)
        #expect(HeaderRowDetector.index(in: []) == nil)
    }

    @Test(
        "Numeric detection accepts money and separators but not labels",
        arguments: [
            ("12", true), ("1,200.50", true), ("₹560", true), ("-450", true), ("(450)", true),
            ("01/04/2026", true), ("50%", true),
            ("Qty", false), ("Item 1", false), ("", false), ("N/A", false), ("Amount", false),
        ]
    )
    func numericDetection(text: String, expected: Bool) {
        #expect(HeaderRowDetector.looksNumeric(text) == expected)
    }
}

@Suite("Vision geometry")
struct VisionGeometryTests {
    @Test("Flipping converts bottom-left origin to top-left")
    func flipOrigin() {
        // A box sitting at the very bottom of the page in Vision's coordinates…
        let bottom = VisionGeometry.flip(CGRect(x: 0.1, y: 0.0, width: 0.2, height: 0.05))
        // …is at the very bottom in ours too, measured from the top.
        #expect(bottom.y == 0.95)
        #expect(bottom.x == 0.1)
        #expect(bottom.height == 0.05)
    }

    @Test("A box at the top of the page maps to y = 0")
    func topOfPage() {
        let top = VisionGeometry.flip(CGRect(x: 0, y: 0.9, width: 1, height: 0.1))
        #expect(abs(top.y) < 0.0001)
    }

    @Test("Flipping twice returns the original")
    func flipIsAnInvolution() {
        let original = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.1)
        let once = VisionGeometry.flip(original)
        let twice = VisionGeometry.flip(
            CGRect(x: once.x, y: once.y, width: once.width, height: once.height)
        )
        #expect(abs(twice.y - original.origin.y) < 0.0001)
    }
}
