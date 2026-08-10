import Foundation
import Testing

@testable import CarbonCore

@Suite("CSV export")
struct CSVExporterTests {
    private func template(_ labels: [String]) -> TemplateSnapshot {
        TemplateSnapshot(
            id: UUID(),
            name: "Daily Register",
            mode: .table,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: labels.enumerated().map { index, label in
                FieldSnapshot(
                    id: UUID(),
                    key: "f\(index)",
                    label: label,
                    type: .text,
                    isRequired: false,
                    aliases: [],
                    choices: [],
                    defaultValue: nil,
                    currencyCode: nil,
                    validationPattern: nil,
                    lastKnownFrame: nil
                )
            },
            learnedHeaderAliases: []
        )
    }

    private func record(_ values: [String]) -> RecordSnapshot {
        RecordSnapshot(
            id: UUID(),
            capturedAt: .now,
            status: .confirmed,
            sourceRowIndex: 0,
            values: values.enumerated().map { index, value in
                FieldValueSnapshot(
                    id: UUID(),
                    fieldKey: "f\(index)",
                    rawText: value,
                    normalizedValue: value,
                    confidence: 1,
                    source: .deterministic,
                    wasEditedByUser: false,
                    frame: nil
                )
            }
        )
    }

    /// The file as text, with the BOM removed so assertions read clearly.
    private func text(_ data: Data) -> String {
        String(decoding: data.dropFirst(3), as: UTF8.self)
    }

    @Test("The file starts with a byte-order mark so Excel on Windows reads it as UTF-8")
    func byteOrderMark() throws {
        let data = try CSVExporter().csv(records: [], template: template(["Item"]))
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    @Test("Header uses field labels, and rows follow in declared column order")
    func headerAndOrder() throws {
        let data = try CSVExporter().csv(
            records: [record(["01/04/2026", "Sugar", "1440.00"])],
            template: template(["Date", "Item", "Amount"])
        )
        #expect(text(data) == "Date,Item,Amount\r\n01/04/2026,Sugar,1440.00\r\n")
    }

    @Test("Records are separated by CRLF, as the spec requires")
    func crlf() throws {
        let data = try CSVExporter().csv(
            records: [record(["a"]), record(["b"])],
            template: template(["X"])
        )
        #expect(text(data) == "X\r\na\r\nb\r\n")
    }

    @Test("A value containing a comma is quoted")
    func embeddedComma() throws {
        let data = try CSVExporter().csv(
            records: [record(["Rice, basmati"])],
            template: template(["Item"])
        )
        #expect(text(data) == "Item\r\n\"Rice, basmati\"\r\n")
    }

    @Test("A quote inside a value is doubled and the value quoted")
    func embeddedQuote() throws {
        let data = try CSVExporter().csv(
            records: [record(["5\" pipe"])],
            template: template(["Item"])
        )
        #expect(text(data) == "Item\r\n\"5\"\" pipe\"\r\n")
    }

    @Test("A newline inside a value is preserved inside quotes rather than breaking the row")
    func embeddedNewline() throws {
        let data = try CSVExporter().csv(
            records: [record(["Line one\nLine two"])],
            template: template(["Notes"])
        )
        #expect(text(data) == "Notes\r\n\"Line one\nLine two\"\r\n")
    }

    @Test("A value that is only quotes survives")
    func onlyQuotes() throws {
        let data = try CSVExporter().csv(records: [record(["\"\""])], template: template(["X"]))
        #expect(text(data) == "X\r\n\"\"\"\"\"\"\r\n")
    }

    @Test("Leading and trailing spaces are quoted so readers cannot trim them away")
    func surroundingSpaces() throws {
        let data = try CSVExporter().csv(records: [record([" 42 "])], template: template(["Qty"]))
        #expect(text(data) == "Qty\r\n\" 42 \"\r\n")
    }

    @Test("A field with no stored value exports as empty, keeping every row the same width")
    func missingValuesKeepColumnCount() throws {
        let sparse = RecordSnapshot(
            id: UUID(), capturedAt: .now, status: .needsReview, sourceRowIndex: 0,
            values: [
                FieldValueSnapshot(
                    id: UUID(), fieldKey: "f1", rawText: "Sugar", normalizedValue: "Sugar",
                    confidence: 1, source: .deterministic, wasEditedByUser: false, frame: nil
                )
            ]
        )
        let data = try CSVExporter().csv(
            records: [sparse], template: template(["Date", "Item", "Amount"])
        )
        #expect(text(data) == "Date,Item,Amount\r\n,Sugar,\r\n")
    }

    @Test("Unicode survives the round trip")
    func unicode() throws {
        let data = try CSVExporter().csv(
            records: [record(["₹1,440.00", "हल्दी पाउडर", "café"])],
            template: template(["Amount", "Item", "Notes"])
        )
        // The rupee value contains a comma, so it must arrive quoted.
        #expect(text(data) == "Amount,Item,Notes\r\n\"₹1,440.00\",हल्दी पाउडर,café\r\n")
    }

    @Test("An empty dataset still produces a usable file with its header")
    func emptyDataset() throws {
        let data = try CSVExporter().csv(records: [], template: template(["Date", "Item"]))
        #expect(text(data) == "Date,Item\r\n")
    }

    @Test("A thousand records export well inside the budget")
    func performance() throws {
        let rows = (0..<1000).map { record(["01/04/2026", "Item \($0)", "\($0).00"]) }
        let started = ContinuousClock.now
        let data = try CSVExporter().csv(records: rows, template: template(["Date", "Item", "Amount"]))
        let elapsed = ContinuousClock.now - started

        #expect(elapsed < .seconds(1), "the budget is one second for a thousand records")
        #expect(text(data).split(separator: "\r\n").count == 1001)
    }

    @Test(
        "Escaping quotes only what needs it",
        arguments: [
            ("Sugar", "Sugar"),
            ("1440.00", "1440.00"),
            ("", ""),
            ("a,b", "\"a,b\""),
            ("a\"b", "\"a\"\"b\""),
            ("a\rb", "\"a\rb\""),
        ]
    )
    func escaping(input: String, expected: String) {
        #expect(CSVExporter.escape(input) == expected)
    }

    @Test("The filename carries the template name and the date")
    func fileName() {
        let name = CSVExporter.fileName(
            for: template(["X"]), date: Date(timeIntervalSince1970: 1_775_000_000)
        )
        #expect(name.hasPrefix("Daily Register "))
        #expect(name.hasSuffix(".csv"))
    }

    @Test("A template name containing a path separator cannot produce a nested filename")
    func fileNameIsSafe() {
        let awkward = TemplateSnapshot(
            id: UUID(), name: "04/2026: Register", mode: .table,
            dateConvention: .dayMonthYear, preferredDateFormat: nil,
            fields: [], learnedHeaderAliases: []
        )
        let name = CSVExporter.fileName(for: awkward)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }
}
