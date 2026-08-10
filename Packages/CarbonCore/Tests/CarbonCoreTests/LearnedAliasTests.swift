import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("Learned header aliases")
struct LearnedAliasTests {
    private func makeStore() throws -> CarbonStore {
        let container = try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CarbonStore(modelContainer: container)
    }

    private func cell(_ text: String, _ row: Int, _ column: Int) -> RecognizedCell {
        RecognizedCell(
            text: text,
            frame: NormalizedRect(
                x: 0.2 * Double(column), y: 0.1 * Double(row), width: 0.18, height: 0.05
            ),
            rowRange: row...row,
            columnRange: column...column,
            recognitionConfidence: 0.95
        )
    }

    private func page(header: [String], rows: [[String]]) -> RecognizedPage {
        let all = [header] + rows
        return RecognizedPage(
            pageID: UUID(),
            blocks: [],
            tables: [
                RecognizedTable(
                    frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    rows: all.enumerated().map { rowIndex, row in
                        row.enumerated().map { cell($1, rowIndex, $0) }
                    },
                    headerRowIndex: 0
                )
            ],
            detectedData: [],
            fullText: ""
        )
    }

    @Test("A header matched by fuzzy comparison is remembered as an alias")
    func learnsInexactMatch() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )
        let template = try #require(try await store.templateSnapshot(id: templateID))

        // "Arnount" is what recognition does to "Amount" at small sizes.
        let result = await DeterministicExtractor()
            .extract(page: page(header: ["Arnount"], rows: [["1440.00"]]), template: template)

        #expect(result.aliasesToLearn["amount"] == "Arnount")

        try await store.save(result, templateID: templateID)

        let after = try #require(try await store.templateSnapshot(id: templateID))
        #expect(after.field(forKey: "amount")?.aliases.contains("arnount") == true)
    }

    @Test("Learning turns next week's guess into next week's exact match")
    func learningImprovesTheNextRun() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )

        let first = try #require(try await store.templateSnapshot(id: templateID))
        let firstRun = await DeterministicExtractor()
            .extract(page: page(header: ["Arnount"], rows: [["1440.00"]]), template: first)
        let firstConfidence = firstRun.records[0].value(forKey: "amount")?.confidence ?? 0
        try await store.save(firstRun, templateID: templateID)

        let second = try #require(try await store.templateSnapshot(id: templateID))
        let secondRun = await DeterministicExtractor()
            .extract(page: page(header: ["Arnount"], rows: [["1440.00"]]), template: second)
        let secondConfidence = secondRun.records[0].value(forKey: "amount")?.confidence ?? 0

        #expect(
            secondConfidence > firstConfidence,
            "the same page should read more confidently once the header is known"
        )
        // Nothing left to learn from a header it now matches exactly.
        #expect(secondRun.aliasesToLearn.isEmpty)
    }

    @Test("An exact match teaches nothing, so the alias list does not grow forever")
    func exactMatchesAreNotLearned() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )
        let template = try #require(try await store.templateSnapshot(id: templateID))

        let result = await DeterministicExtractor()
            .extract(page: page(header: ["Amount"], rows: [["1440.00"]]), template: template)

        #expect(result.aliasesToLearn.isEmpty)
    }

    @Test("The same header in a different case is not stored twice")
    func caseInsensitiveDeduplication() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )

        for header in ["Arnount", "ARNOUNT", "arnount"] {
            let template = try #require(try await store.templateSnapshot(id: templateID))
            let result = await DeterministicExtractor()
                .extract(page: page(header: [header], rows: [["1440.00"]]), template: template)
            try await store.save(result, templateID: templateID)
        }

        let after = try #require(try await store.templateSnapshot(id: templateID))
        let learned = after.field(forKey: "amount")?.aliases.filter { $0 == "arnount" } ?? []
        #expect(learned.count == 1)
    }

    @Test("An abbreviation too far from the label is not matched, and so is not learned")
    func abbreviationsAreNotGuessedAt() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )
        let template = try #require(try await store.templateSnapshot(id: templateID))

        // "Amt" scores 0.5 against "Amount" — below the match threshold. Learning only ever
        // fires on a header that *did* match, so this mechanism improves recognition of
        // misread headers, not of human shorthand. Shorthand is what declared columnAliases
        // are for, and inventing a match here would bind a column on a coin toss.
        let result = await DeterministicExtractor()
            .extract(page: page(header: ["Amt"], rows: [["1440.00"]]), template: template)

        #expect(result.aliasesToLearn.isEmpty)
        #expect(result.records[0].value(forKey: "amount")?.source == .unresolved)
    }

    @Test("A page read positionally teaches nothing, because a position is not a name")
    func positionalMatchesTeachNothing() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )
        let template = try #require(try await store.templateSnapshot(id: templateID))

        // No header row at all.
        let headerless = RecognizedPage(
            pageID: UUID(),
            blocks: [],
            tables: [
                RecognizedTable(
                    frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    rows: [[cell("1440.00", 0, 0)]],
                    headerRowIndex: nil
                )
            ],
            detectedData: [],
            fullText: ""
        )

        let result = await DeterministicExtractor().extract(page: headerless, template: template)
        #expect(result.aliasesToLearn.isEmpty)
    }

    @Test("The ladder carries what Tier 1 learned rather than dropping it")
    func ladderPreservesLearning() async throws {
        let store = try makeStore()
        let templateID = try await store.createTemplate(
            name: "Register",
            mode: .table,
            fields: [NewFieldSpec(label: "Amount", type: .currency)]
        )
        let template = try #require(try await store.templateSnapshot(id: templateID))

        let result = await LadderExtractor(resolver: nil)
            .extract(page: page(header: ["Arnount"], rows: [["1440.00"]]), template: template)

        #expect(result.aliasesToLearn["amount"] == "Arnount")
    }
}
