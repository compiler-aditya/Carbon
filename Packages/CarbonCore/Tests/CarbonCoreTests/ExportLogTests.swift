import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("Export logging")
struct ExportLogTests {
    private func makeStore() throws -> CarbonStore {
        let container = try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CarbonStore(modelContainer: container)
    }

    @Test("No exports yet reads as empty rather than as zeroes with a date")
    func emptySummary() async throws {
        let store = try makeStore()
        let summary = try await store.exportSummary()
        #expect(summary == .empty)
        #expect(summary.lastExportedAt == nil)
    }

    @Test("Summary totals the exports and their records")
    func summaryTotals() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register", fields: [NewFieldSpec(label: "Item")]
        )

        try await store.logExport(
            templateID: templateID, recordCount: 14, fileName: "a.csv",
            at: Date(timeIntervalSince1970: 1_000)
        )
        try await store.logExport(
            templateID: templateID, recordCount: 6, fileName: "b.csv",
            at: Date(timeIntervalSince1970: 2_000)
        )

        let summary = try await store.exportSummary()
        #expect(summary.exportCount == 2)
        #expect(summary.recordCount == 20)
        #expect(summary.lastExportedAt == Date(timeIntervalSince1970: 2_000))
    }

    @Test("A full export round trip produces bytes and a log entry that agree")
    func roundTrip() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Daily Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Item"), NewFieldSpec(label: "Amount", type: .currency)]
        )

        let extraction = ExtractionResult(
            records: [
                ExtractedRecord(
                    sourceRowIndex: 0,
                    values: [
                        ExtractedValue(
                            fieldKey: "item", rawText: "Rice, basmati",
                            normalized: "Rice, basmati", confidence: 0.95,
                            source: .deterministic, frame: nil
                        ),
                        ExtractedValue(
                            fieldKey: "amount", rawText: "₹6,720.00", normalized: "6720.00",
                            confidence: 0.95, source: .deterministic, frame: nil
                        ),
                    ]
                )
            ],
            pageID: UUID(), durationMs: 12, engineVersion: "test", diagnostics: []
        )
        try await store.save(extraction, templateID: templateID)

        let template = try #require(try await store.templateSnapshot(id: templateID))
        let records = try await store.records(matching: RecordQuery(templateID: templateID))
        let data = try CSVExporter().csv(records: records, template: template)

        let text = String(decoding: data.dropFirst(3), as: UTF8.self)
        // The comma inside the item name must survive as one field, not split the row.
        #expect(text == "Item,Amount\r\n\"Rice, basmati\",6720.00\r\n")

        let fileName = CSVExporter.fileName(for: template)
        try await store.logExport(
            templateID: templateID, recordCount: records.count, fileName: fileName
        )

        let summary = try await store.exportSummary()
        #expect(summary.exportCount == 1)
        #expect(summary.recordCount == 1)
    }
}
