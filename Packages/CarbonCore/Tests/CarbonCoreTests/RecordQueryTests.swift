import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("Dataset queries")
struct RecordQueryTests {
    private func makeStore() throws -> CarbonStore {
        let container = try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CarbonStore(modelContainer: container)
    }

    private let fields = [
        NewFieldSpec(label: "Item", type: .text),
        NewFieldSpec(label: "Amount", type: .currency),
    ]

    /// Seeds a register: three confident rows and one doubtful one.
    private func seed(_ store: CarbonStore) async throws -> UUID {
        let templateID = try await store.createTemplate(
            name: "Daily Register", mode: .table, fields: fields
        )

        let rows: [(String, String, Double)] = [
            ("Basmati rice 5kg", "6720.00", 0.95),
            ("Mustard oil 1L", "1484.00", 0.94),
            ("Sugar 1kg", "9.00", 0.93),
            ("Turmeric powder", "1008.00", 0.30),
        ]

        for (index, row) in rows.enumerated() {
            let result = ExtractionResult(
                records: [
                    ExtractedRecord(
                        sourceRowIndex: index,
                        values: [
                            ExtractedValue(
                                fieldKey: "item", rawText: row.0, normalized: row.0,
                                confidence: row.2, source: .deterministic, frame: nil
                            ),
                            ExtractedValue(
                                fieldKey: "amount", rawText: row.1, normalized: row.1,
                                confidence: row.2, source: .deterministic, frame: nil
                            ),
                        ]
                    )
                ],
                pageID: UUID(), durationMs: 10, engineVersion: "test", diagnostics: []
            )
            // Staggered so ordering is unambiguous.
            try await store.save(
                result,
                templateID: templateID,
                capturedAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(index) * 60)
            )
        }
        return templateID
    }

    @Test("Newest first by default, oldest first on request")
    func ordering() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)

        let newest = try await store.records(matching: RecordQuery(templateID: templateID))
        #expect(newest.first?.exportValue(forKey: "item") == "Turmeric powder")

        let oldest = try await store.records(
            matching: RecordQuery(templateID: templateID, sort: .oldest)
        )
        #expect(oldest.first?.exportValue(forKey: "item") == "Basmati rice 5kg")
    }

    @Test("Filters split the dataset by status")
    func filtering() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)

        let all = try await store.records(matching: RecordQuery(templateID: templateID))
        let doubtful = try await store.records(
            matching: RecordQuery(templateID: templateID, filter: .needsReview)
        )
        let confirmed = try await store.records(
            matching: RecordQuery(templateID: templateID, filter: .confirmed)
        )

        #expect(all.count == 4)
        #expect(doubtful.count == 1)
        #expect(doubtful.first?.exportValue(forKey: "item") == "Turmeric powder")
        #expect(confirmed.count == 3)
    }

    @Test("Search looks across every value, not just one field")
    func search() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)

        let byItem = try await store.records(
            matching: RecordQuery(templateID: templateID, searchText: "mustard")
        )
        #expect(byItem.count == 1, "search should be case-insensitive")

        // 1484.00 is an amount, not an item — search has to reach it too.
        let byAmount = try await store.records(
            matching: RecordQuery(templateID: templateID, searchText: "1484")
        )
        #expect(byAmount.count == 1)

        let nothing = try await store.records(
            matching: RecordQuery(templateID: templateID, searchText: "kerosene")
        )
        #expect(nothing.isEmpty)
    }

    @Test("Sorting by a field is numeric-aware, so 9 comes before 100")
    func fieldSortIsNumericAware() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)

        let byAmount = try await store.records(
            matching: RecordQuery(templateID: templateID, sort: .field(key: "amount"))
        )
        #expect(
            byAmount.map { $0.exportValue(forKey: "amount") }
                == ["9.00", "1008.00", "1484.00", "6720.00"]
        )
    }

    @Test("Limit and offset page through the results")
    func pagination() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)

        let firstPage = try await store.records(
            matching: RecordQuery(templateID: templateID, sort: .oldest, limit: 2)
        )
        let secondPage = try await store.records(
            matching: RecordQuery(templateID: templateID, sort: .oldest, limit: 2, offset: 2)
        )

        #expect(firstPage.map { $0.exportValue(forKey: "item") } == ["Basmati rice 5kg", "Mustard oil 1L"])
        #expect(secondPage.map { $0.exportValue(forKey: "item") } == ["Sugar 1kg", "Turmeric powder"])
    }

    @Test("Counts drive the filter chips")
    func counts() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)

        let counts = try await store.recordCounts(templateID: templateID)
        #expect(counts[.all] == 4)
        #expect(counts[.needsReview] == 1)
        #expect(counts[.confirmed] == 3)
    }

    @Test("Confirming re-derives status and leaves genuinely doubtful records alone")
    func confirming() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)
        let all = try await store.records(matching: RecordQuery(templateID: templateID))

        try await store.confirmRecords(ids: all.map(\.id))

        let stillDoubtful = try await store.records(
            matching: RecordQuery(templateID: templateID, filter: .needsReview)
        )
        #expect(
            stillDoubtful.count == 1,
            "confirming is not a way to silence a low-confidence value without looking at it"
        )
    }

    @Test("One template's records never leak into another's")
    func templateIsolation() async throws {
        let store = try makeStore()
        let templateID = try await seed(store)
        let other = try await store.createTemplate(name: "Intake", fields: fields)

        #expect(try await store.records(matching: RecordQuery(templateID: other)).isEmpty)
        #expect(try await store.records(matching: RecordQuery(templateID: templateID)).count == 4)
    }
}
