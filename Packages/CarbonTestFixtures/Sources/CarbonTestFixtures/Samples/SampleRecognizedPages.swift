import CarbonCore
import Foundation

/// Recognised pages built by hand, so the whole extraction ladder can be exercised with no
/// camera, no Vision and no model.
///
/// This is what makes the app explorable on a simulator — which is very likely how it is
/// first opened by someone who did not build it.
public enum SampleRecognizedPages {
    public static let dailyRegisterPageID = UUID(uuidString: "9A9E0000-0000-4000-A000-000000000001")!

    /// A clean, well-lit register page: a header row and eight ruled rows.
    public static var dailyRegister: RecognizedPage {
        makeRegisterPage(rows: cleanRegisterRows, confidence: 0.94)
    }

    /// The same page photographed badly. Confidence drops into the review band and one cell
    /// is genuinely unreadable, so the review screen has something real to show.
    public static var dailyRegisterPoorScan: RecognizedPage {
        var rows = cleanRegisterRows
        rows[2][1] = "Turmeric ??wder"
        rows[4][3] = ""
        return makeRegisterPage(rows: rows, confidence: 0.52)
    }

    /// A page with no table at all — what a table-mode template meets when someone scans the
    /// wrong sheet.
    public static var pageWithoutTable: RecognizedPage {
        RecognizedPage(
            pageID: UUID(),
            blocks: [
                RecognizedBlock(
                    text: "Notice of inspection",
                    frame: NormalizedRect(x: 0.1, y: 0.08, width: 0.8, height: 0.05),
                    recognitionConfidence: 0.97
                )
            ],
            tables: [],
            detectedData: [],
            fullText: "Notice of inspection"
        )
    }

    private static let header = ["Date", "Item", "Qty", "Rate", "Amount"]

    private static let cleanRegisterRows: [[String]] = [
        ["01/04/2026", "Basmati rice 5kg", "12", "560.00", "6720.00"],
        ["01/04/2026", "Mustard oil 1L", "8", "185.50", "1484.00"],
        ["01/04/2026", "Turmeric powder", "24", "42.00", "1008.00"],
        ["02/04/2026", "Wheat flour 10kg", "6", "410.00", "2460.00"],
        ["02/04/2026", "Sugar 1kg", "30", "48.00", "1440.00"],
        ["02/04/2026", "Tea leaves 500g", "15", "260.00", "3900.00"],
        ["03/04/2026", "Basmati rice 5kg", "9", "560.00", "5040.00"],
        ["03/04/2026", "Cardamom 100g", "4", "320.00", "1280.00"],
    ]

    private static func makeRegisterPage(rows: [[String]], confidence: Double) -> RecognizedPage {
        let allRows = [header] + rows
        let rowHeight = 0.06
        let top = 0.12

        let cells: [[RecognizedCell]] = allRows.enumerated().map { rowIndex, row in
            row.enumerated().map { columnIndex, text in
                RecognizedCell(
                    text: text,
                    frame: NormalizedRect(
                        x: 0.06 + Double(columnIndex) * 0.18,
                        y: top + Double(rowIndex) * rowHeight,
                        width: 0.17,
                        height: rowHeight - 0.01
                    ),
                    rowRange: rowIndex...rowIndex,
                    columnRange: columnIndex...columnIndex,
                    // The header is printed; only the handwritten entries degrade on a bad scan.
                    recognitionConfidence: rowIndex == 0 ? 0.98 : confidence
                )
            }
        }

        let table = RecognizedTable(
            frame: NormalizedRect(x: 0.05, y: 0.1, width: 0.9, height: rowHeight * Double(allRows.count)),
            rows: cells,
            headerRowIndex: 0
        )

        return RecognizedPage(
            pageID: dailyRegisterPageID,
            blocks: [
                RecognizedBlock(
                    text: "Daily Sales Register",
                    frame: NormalizedRect(x: 0.06, y: 0.04, width: 0.5, height: 0.04),
                    recognitionConfidence: 0.99
                )
            ],
            tables: [table],
            detectedData: [],
            fullText: (["Daily Sales Register"] + allRows.map { $0.joined(separator: "  ") })
                .joined(separator: "\n")
        )
    }
}
