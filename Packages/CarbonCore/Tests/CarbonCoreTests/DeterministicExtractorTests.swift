import Foundation
import Testing

@testable import CarbonCore

@Suite("Tier 1 deterministic extraction")
struct DeterministicExtractorTests {
    // MARK: Fixtures

    private func field(
        _ key: String,
        _ label: String,
        _ type: FieldType,
        aliases: [String] = [],
        defaultValue: String? = nil
    ) -> FieldSnapshot {
        FieldSnapshot(
            id: UUID(),
            key: key,
            label: label,
            type: type,
            isRequired: false,
            aliases: ([label] + aliases).map { $0.lowercased() },
            choices: [],
            defaultValue: defaultValue,
            currencyCode: nil,
            validationPattern: nil,
            lastKnownFrame: nil
        )
    }

    private var registerTemplate: TemplateSnapshot {
        TemplateSnapshot(
            id: UUID(),
            name: "Daily Register",
            mode: .table,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [
                field("date", "Date", .text),
                field("item", "Item", .text, aliases: ["particulars"]),
                field("quantity", "Quantity", .integer, aliases: ["qty"]),
                field("amount", "Amount", .currency, aliases: ["amt"]),
            ],
            learnedHeaderAliases: []
        )
    }

    private func cell(_ text: String, row: Int, column: Int, confidence: Double = 0.95)
        -> RecognizedCell
    {
        RecognizedCell(
            text: text,
            frame: NormalizedRect(
                x: 0.05 + Double(column) * 0.2, y: 0.1 + Double(row) * 0.05,
                width: 0.19, height: 0.04
            ),
            rowRange: row...row,
            columnRange: column...column,
            recognitionConfidence: confidence
        )
    }

    private func table(_ texts: [[String]], headerRowIndex: Int?, confidence: Double = 0.95)
        -> RecognizedPage
    {
        let rows = texts.enumerated().map { rowIndex, row in
            row.enumerated().map {
                cell($1, row: rowIndex, column: $0, confidence: confidence)
            }
        }
        return RecognizedPage(
            pageID: UUID(),
            blocks: [],
            tables: [
                RecognizedTable(
                    frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    rows: rows,
                    headerRowIndex: headerRowIndex
                )
            ],
            detectedData: [],
            fullText: ""
        )
    }

    // MARK: Table mode

    @Test("A clean register produces one record per data row, with columns in the right fields")
    func cleanRegister() async {
        let page = table(
            [
                ["Date", "Item", "Qty", "Amount"],
                ["01/04/2026", "Basmati rice 5kg", "12", "6720.00"],
                ["02/04/2026", "Sugar 1kg", "30", "1440.00"],
            ],
            headerRowIndex: 0
        )

        let result = await DeterministicExtractor().extract(page: page, template: registerTemplate)

        #expect(result.records.count == 2)
        let first = result.records[0]
        #expect(first.value(forKey: "item")?.normalized == "Basmati rice 5kg")
        #expect(first.value(forKey: "quantity")?.normalized == "12")
        #expect(first.value(forKey: "amount")?.normalized == "6720.00")
        #expect(first.resolvedStatus == .confirmed)
        #expect(result.deterministicShare == 1.0)
    }

    @Test("Header order does not have to match the order the fields were declared in")
    func columnsMatchedByNameNotPosition() async {
        let page = table(
            [
                ["Amount", "Date", "Qty", "Item"],
                ["6720.00", "01/04/2026", "12", "Basmati rice 5kg"],
            ],
            headerRowIndex: 0
        )

        let record = await DeterministicExtractor()
            .extract(page: page, template: registerTemplate).records[0]

        #expect(record.value(forKey: "amount")?.normalized == "6720.00")
        #expect(record.value(forKey: "item")?.normalized == "Basmati rice 5kg")
    }

    @Test("A declared alias matches a header the field's label does not")
    func aliasMatching() async {
        let page = table(
            [["Date", "Particulars", "Qty", "Amt"], ["01/04/2026", "Sugar", "30", "1440.00"]],
            headerRowIndex: 0
        )

        let record = await DeterministicExtractor()
            .extract(page: page, template: registerTemplate).records[0]

        #expect(record.value(forKey: "item")?.normalized == "Sugar")
        #expect(record.value(forKey: "amount")?.normalized == "1440.00")
    }

    @Test("A misread header still matches, because exact matching would waste a readable column")
    func fuzzyHeaderMatching() async {
        // "Arnount" is what recognition does to "Amount" at small sizes.
        let page = table(
            [["Date", "Item", "Otv", "Arnount"], ["01/04/2026", "Sugar", "30", "1440.00"]],
            headerRowIndex: 0
        )

        let record = await DeterministicExtractor()
            .extract(page: page, template: registerTemplate).records[0]

        #expect(record.value(forKey: "amount")?.normalized == "1440.00")
    }

    @Test("A header that matches nothing leaves its field unresolved rather than guessing")
    func unmatchedColumnIsUnresolved() async {
        let page = table(
            [["Date", "Item", "Qty", "Signature"], ["01/04/2026", "Sugar", "30", "PS"]],
            headerRowIndex: 0
        )

        let result = await DeterministicExtractor().extract(page: page, template: registerTemplate)
        let record = result.records[0]

        #expect(record.value(forKey: "amount")?.source == .unresolved)
        #expect(record.resolvedStatus == .needsReview)
        #expect(result.diagnostics.contains { $0.contains("amount") })
    }

    @Test("Ragged rows do not crash and produce unresolved values for the missing cells")
    func raggedRows() async {
        let page = table(
            [
                ["Date", "Item", "Qty", "Amount"],
                ["01/04/2026", "Sugar", "30", "1440.00"],
                ["02/04/2026", "Tea"],
            ],
            headerRowIndex: 0
        )

        let result = await DeterministicExtractor().extract(page: page, template: registerTemplate)

        #expect(result.records.count == 2)
        #expect(result.records[1].value(forKey: "item")?.normalized == "Tea")
        #expect(result.records[1].value(forKey: "amount")?.source == .unresolved)
    }

    @Test("An empty cell is unresolved, not an empty confident value")
    func emptyCell() async {
        let page = table(
            [["Date", "Item", "Qty", "Amount"], ["01/04/2026", "Sugar", "", "1440.00"]],
            headerRowIndex: 0
        )

        let record = await DeterministicExtractor()
            .extract(page: page, template: registerTemplate).records[0]

        #expect(record.value(forKey: "quantity")?.source == .unresolved)
        #expect(record.value(forKey: "quantity")?.confidence == 0)
    }

    @Test("With no header row, columns are read in declared order and everything needs review")
    func positionalFallback() async {
        let page = table(
            [["01/04/2026", "Sugar", "30", "1440.00"]],
            headerRowIndex: nil
        )

        let result = await DeterministicExtractor().extract(page: page, template: registerTemplate)
        let record = result.records[0]

        #expect(record.value(forKey: "item")?.normalized == "Sugar")
        // Read positionally, so it is a guess and is scored as one.
        #expect(record.resolvedStatus == .needsReview)
        #expect(result.diagnostics.contains { $0.contains("positionally") })
    }

    @Test("A table-mode template meeting a page with no table yields no records, not a crash")
    func noTableOnPage() async {
        let page = RecognizedPage(
            pageID: UUID(), blocks: [], tables: [], detectedData: [], fullText: "Notice"
        )

        let result = await DeterministicExtractor().extract(page: page, template: registerTemplate)

        #expect(result.records.isEmpty)
        #expect(result.diagnostics.contains { $0.contains("no table") })
    }

    @Test("A poorly-read cell drags its value into the review band even when mapping is certain")
    func lowRecognitionConfidenceNeedsReview() async {
        let page = table(
            [["Date", "Item", "Qty", "Amount"], ["01/04/2026", "Sugar", "30", "1440.00"]],
            headerRowIndex: 0,
            confidence: 0.5
        )

        let record = await DeterministicExtractor()
            .extract(page: page, template: registerTemplate).records[0]

        #expect(record.resolvedStatus == .needsReview)
    }

    @Test("Values are normalized on the way through, so the tier cannot change the meaning")
    func valuesAreNormalized() async {
        let page = table(
            [["Date", "Item", "Qty", "Amount"], ["01/04/2026", "  Sugar  1kg ", "30", "₹1,440.00"]],
            headerRowIndex: 0
        )

        let record = await DeterministicExtractor()
            .extract(page: page, template: registerTemplate).records[0]

        #expect(record.value(forKey: "item")?.normalized == "Sugar 1kg")
        #expect(record.value(forKey: "amount")?.normalized == "1440.00")
        // rawText keeps exactly what was on the page. This pair is the accuracy dataset.
        #expect(record.value(forKey: "amount")?.rawText == "₹1,440.00")
    }

    @Test("A declared default fills an unmatched field and says it is a default")
    func defaultValueApplied() async {
        let template = TemplateSnapshot(
            id: UUID(),
            name: "Register",
            mode: .table,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [
                field("item", "Item", .text),
                field("branch", "Branch", .text, defaultValue: "Main"),
            ],
            learnedHeaderAliases: []
        )
        let page = table([["Item"], ["Sugar"]], headerRowIndex: 0)

        let record = await DeterministicExtractor().extract(page: page, template: template).records[0]

        #expect(record.value(forKey: "branch")?.normalized == "Main")
        #expect(record.value(forKey: "branch")?.source == .defaultValue)
    }

    // MARK: Record mode

    @Test("Record mode reads the value to the right of each label")
    func recordModeLabelAnchoring() async {
        func block(_ text: String, x: Double, y: Double) -> RecognizedBlock {
            RecognizedBlock(
                text: text,
                frame: NormalizedRect(x: x, y: y, width: 0.25, height: 0.04),
                recognitionConfidence: 0.95
            )
        }

        let page = RecognizedPage(
            pageID: UUID(),
            blocks: [
                block("Name:", x: 0.05, y: 0.10),
                block("Priya Sharma", x: 0.35, y: 0.10),
                block("Phone:", x: 0.05, y: 0.20),
                block("9876543210", x: 0.35, y: 0.20),
            ],
            tables: [],
            detectedData: [],
            fullText: ""
        )

        let template = TemplateSnapshot(
            id: UUID(),
            name: "Intake",
            mode: .record,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [field("name", "Name", .text), field("phone", "Phone", .phone)],
            learnedHeaderAliases: []
        )

        let result = await DeterministicExtractor().extract(page: page, template: template)

        #expect(result.records.count == 1)
        #expect(result.records[0].value(forKey: "name")?.normalized == "Priya Sharma")
        #expect(result.records[0].value(forKey: "phone")?.normalized == "9876543210")
    }

    @Test("Record mode leaves a field unresolved when its label is not on the page")
    func recordModeMissingLabel() async {
        let page = RecognizedPage(
            pageID: UUID(),
            blocks: [
                RecognizedBlock(
                    text: "Something else entirely",
                    frame: NormalizedRect(x: 0.05, y: 0.1, width: 0.5, height: 0.04),
                    recognitionConfidence: 0.9
                )
            ],
            tables: [],
            detectedData: [],
            fullText: ""
        )
        let template = TemplateSnapshot(
            id: UUID(),
            name: "Intake",
            mode: .record,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [field("name", "Name", .text)],
            learnedHeaderAliases: []
        )

        let record = await DeterministicExtractor().extract(page: page, template: template).records[0]
        #expect(record.value(forKey: "name")?.source == .unresolved)
    }
}
