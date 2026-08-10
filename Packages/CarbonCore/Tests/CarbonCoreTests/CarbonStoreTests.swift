import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("Store: write path and CRUD")
struct CarbonStoreTests {
    private func makeStore() throws -> CarbonStore {
        let container = try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CarbonStore(modelContainer: container)
    }

    private func makePageStore() throws -> (LivePageStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "carbon-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (try LivePageStore(rootDirectory: root), root)
    }

    private func makeImage() -> CGImage {
        let context = CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private let registerFields = [
        NewFieldSpec(label: "Date", type: .text),
        NewFieldSpec(label: "Item", type: .text),
        NewFieldSpec(label: "Amount", type: .currency),
    ]

    private func extraction(rows: [[String: String]], confidence: Double = 0.95) -> ExtractionResult {
        ExtractionResult(
            records: rows.enumerated().map { index, row in
                ExtractedRecord(
                    sourceRowIndex: index,
                    values: row.map { key, value in
                        ExtractedValue(
                            fieldKey: key,
                            rawText: value,
                            normalized: value,
                            confidence: confidence,
                            source: .deterministic,
                            frame: NormalizedRect(x: 0.1, y: 0.2, width: 0.2, height: 0.05)
                        )
                    }
                )
            },
            pageID: UUID(),
            durationMs: 87,
            engineVersion: "test-1",
            diagnostics: []
        )
    }

    // MARK: Template CRUD

    @Test("Creating a template freezes a machine key per field")
    func createTemplateGeneratesKeys() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(
            name: "Daily Register", mode: .table, fields: registerFields
        )

        let snapshot = try #require(try await store.templateSnapshot(id: id))
        #expect(snapshot.fields.map(\.key) == ["date", "item", "amount"])
        #expect(snapshot.mode == .table)
    }

    @Test("Duplicate labels get distinct keys rather than colliding on one CSV column")
    func duplicateLabels() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(
            name: "Odd form",
            fields: [NewFieldSpec(label: "Date"), NewFieldSpec(label: "Date")]
        )

        let snapshot = try #require(try await store.templateSnapshot(id: id))
        #expect(snapshot.fields.map(\.key) == ["date", "date_2"])
    }

    @Test("Renaming a label leaves the key alone, so exports keep working")
    func renameKeepsKey() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(name: "Register", fields: registerFields)

        try await store.renameField(templateID: id, key: "amount", newLabel: "Total value")

        let snapshot = try #require(try await store.templateSnapshot(id: id))
        let field = try #require(snapshot.field(forKey: "amount"))
        #expect(field.label == "Total value")
        #expect(field.key == "amount")
    }

    @Test("Adding a field appends it and does not disturb existing keys")
    func addField() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(name: "Register", fields: registerFields)

        let key = try await store.addField(to: id, spec: NewFieldSpec(label: "Quantity", type: .integer))

        let snapshot = try #require(try await store.templateSnapshot(id: id))
        #expect(key == "quantity")
        #expect(snapshot.fields.map(\.key) == ["date", "item", "amount", "quantity"])
    }

    @Test("Deleting a field closes the gap so a later append cannot collide")
    func deleteFieldKeepsOrderContiguous() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(name: "Register", fields: registerFields)

        try await store.deleteField(templateID: id, key: "item")
        try await store.addField(to: id, spec: NewFieldSpec(label: "Quantity"))

        let snapshot = try #require(try await store.templateSnapshot(id: id))
        #expect(snapshot.fields.map(\.key) == ["date", "amount", "quantity"])
    }

    @Test("Reordering applies the given order and parks unnamed fields at the end")
    func reorderFields() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(name: "Register", fields: registerFields)

        try await store.reorderFields(templateID: id, orderedKeys: ["amount", "date"])

        let snapshot = try #require(try await store.templateSnapshot(id: id))
        #expect(snapshot.fields.map(\.key) == ["amount", "date", "item"])
    }

    // MARK: Record write path

    @Test("Each extracted record becomes one stored record with its values")
    func saveRecords() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register", mode: .table, fields: registerFields
        )

        let ids = try await store.save(
            extraction(rows: [
                ["date": "01/04/2026", "item": "Sugar", "amount": "1440.00"],
                ["date": "02/04/2026", "item": "Tea", "amount": "3900.00"],
            ]),
            templateID: templateID,
            rawPageText: "Daily Sales Register"
        )

        #expect(ids.count == 2)

        let snapshots = try await store.recordSnapshots(templateID: templateID)
        #expect(snapshots.count == 2)
        #expect(Set(snapshots.map { $0.exportValue(forKey: "item") }) == ["Sugar", "Tea"])
        #expect(snapshots.allSatisfy { $0.status == .confirmed })
    }

    @Test("A low-confidence value marks its record for review at write time")
    func lowConfidenceNeedsReview() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)

        try await store.save(
            extraction(rows: [["date": "01/04/2026", "amount": "1440.00"]], confidence: 0.4),
            templateID: templateID
        )

        let snapshots = try await store.recordSnapshots(templateID: templateID)
        #expect(snapshots[0].status == .needsReview)
        #expect(snapshots[0].needsReview)
    }

    @Test("Provenance is stamped on, so accuracy can be measured later")
    func provenanceStored() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)

        let ids = try await store.save(
            extraction(rows: [["item": "Sugar"]]),
            templateID: templateID,
            rawPageText: "page text",
            modelWasAvailable: true
        )

        _ = ids
        let snapshot = try await store.recordSnapshots(templateID: templateID)[0]
        #expect(snapshot.engineVersion == "test-1")
        #expect(snapshot.extractionDurationMs == 87)
        #expect(snapshot.modelWasAvailable)
        #expect(snapshot.sourceRowIndex == 0)
    }

    @Test("Frames survive the round trip, so a value can be zoomed to on the source page")
    func framesPersist() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)
        try await store.save(extraction(rows: [["item": "Sugar"]]), templateID: templateID)

        let snapshot = try await store.recordSnapshots(templateID: templateID)[0]
        #expect(snapshot.value(forKey: "item")?.frame?.width == 0.2)
    }

    // MARK: Corrections

    @Test("A correction updates the value, keeps rawText, and clears the review flag")
    func correction() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)
        let ids = try await store.save(
            extraction(rows: [["amount": "l440.00"]], confidence: 0.3),
            templateID: templateID
        )

        try await store.applyCorrection(recordID: ids[0], fieldKey: "amount", newValue: "1440.00")

        let snapshot = try await store.recordSnapshots(templateID: templateID)[0]
        let value = try #require(snapshot.value(forKey: "amount"))
        #expect(value.normalizedValue == "1440.00")
        #expect(value.rawText == "l440.00", "rawText is the accuracy dataset")
        #expect(value.wasCorrected)
        #expect(snapshot.status == .confirmed)
    }

    @Test("A record with another doubtful value stays in review after one correction")
    func correctionLeavesOtherDoubtsAlone() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)
        let ids = try await store.save(
            extraction(rows: [["amount": "l440.00", "item": "Suqar"]], confidence: 0.3),
            templateID: templateID
        )

        try await store.applyCorrection(recordID: ids[0], fieldKey: "amount", newValue: "1440.00")

        let snapshot = try await store.recordSnapshots(templateID: templateID)[0]
        #expect(snapshot.status == .needsReview)
    }

    // MARK: Deletion and file cleanup

    @Test("Deleting a record removes its photographs, not just its rows")
    func deleteRecordPurgesFiles() async throws {
        let store = try makeStore()
        let (pageStore, root) = try makePageStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)
        let captureID = UUID()
        let ref = try await pageStore.persist(makeImage(), captureID: captureID, pageIndex: 0)
        let ids = try await store.save(
            extraction(rows: [["item": "Sugar"]]), templateID: templateID, pages: [ref]
        )

        #expect(try await pageStore.totalBytes() > 0)

        try await store.deleteRecord(id: ids[0], pageStore: pageStore)

        #expect(try await store.recordSnapshots(templateID: templateID).isEmpty)
        #expect(try await pageStore.totalBytes() == 0, "cascade removes rows and leaves files")
    }

    @Test("Deleting a template purges every record's photographs")
    func deleteTemplatePurgesAllFiles() async throws {
        let store = try makeStore()
        let (pageStore, root) = try makePageStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)
        // One photograph, two records — the case that made the old record-keyed layout wrong.
        let captureID = UUID()
        let ref = try await pageStore.persist(makeImage(), captureID: captureID, pageIndex: 0)
        try await store.save(
            extraction(rows: [["item": "Sugar"], ["item": "Tea"]]),
            templateID: templateID,
            pages: [ref]
        )

        try await store.deleteTemplate(id: templateID, pageStore: pageStore)

        #expect(try await store.templateSnapshot(id: templateID) == nil)
        #expect(try await pageStore.totalBytes() == 0)
    }

    @Test("Saving marks the template as used, which is what orders the templates list")
    func saveTouchesLastUsed() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(name: "Register", fields: registerFields)

        let before = try await store.templateSnapshots()
        #expect(before.count == 1)

        try await store.save(extraction(rows: [["item": "Sugar"]]), templateID: templateID)

        let after = try #require(try await store.templateSnapshot(id: templateID))
        #expect(after.lastUsedAt != nil)
        #expect(after.recordCount == 1)
    }

    @Test("Archived templates are hidden from the list but not deleted")
    func archiving() async throws {
        let store = try makeStore()
        let id = try await store.createTemplate(name: "Old form", fields: registerFields)

        try await store.updateTemplate(id: id, isArchived: true)

        #expect(try await store.templateSnapshots().isEmpty)
        #expect(try await store.templateSnapshots(includingArchived: true).count == 1)
        #expect(try await store.templateSnapshot(id: id) != nil)
    }
}
