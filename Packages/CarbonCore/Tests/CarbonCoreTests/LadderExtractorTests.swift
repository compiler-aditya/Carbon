import Foundation
import Testing

@testable import CarbonCore

@Suite("Extraction ladder")
struct LadderExtractorTests {
    /// Answers with whatever it was handed, and records what it was asked.
    private actor StubResolver: ModelFieldResolving {
        private let answers: [String: String]
        private let failure: (any Error)?
        private(set) var askedFor: [String] = []
        private(set) var callCount = 0

        init(answers: [String: String] = [:], failure: (any Error)? = nil) {
            self.answers = answers
            self.failure = failure
        }

        func resolve(
            fields: [FieldSnapshot],
            pageText: String,
            template: TemplateSnapshot
        ) async throws -> [String: String] {
            callCount += 1
            askedFor = fields.map(\.key)
            if let failure { throw failure }
            return answers.filter { key, _ in fields.contains { $0.key == key } }
        }
    }

    private func field(_ key: String, _ label: String, _ type: FieldType = .text) -> FieldSnapshot {
        FieldSnapshot(
            id: UUID(), key: key, label: label, type: type, isRequired: false,
            aliases: [label.lowercased()], choices: [], defaultValue: nil, currencyCode: nil,
            validationPattern: nil, lastKnownFrame: nil
        )
    }

    private func recordTemplate() -> TemplateSnapshot {
        TemplateSnapshot(
            id: UUID(), name: "Intake", mode: .record,
            dateConvention: .dayMonthYear, preferredDateFormat: nil,
            fields: [field("name", "Name"), field("phone", "Phone", .phone)],
            learnedHeaderAliases: []
        )
    }

    /// A page where "Name" is readable and "Phone" is nowhere to be found.
    private func pageWithOnlyName() -> RecognizedPage {
        RecognizedPage(
            pageID: UUID(),
            blocks: [
                RecognizedBlock(
                    text: "Name:",
                    frame: NormalizedRect(x: 0.05, y: 0.1, width: 0.2, height: 0.04),
                    recognitionConfidence: 0.95
                ),
                RecognizedBlock(
                    text: "Priya Sharma",
                    frame: NormalizedRect(x: 0.35, y: 0.1, width: 0.3, height: 0.04),
                    recognitionConfidence: 0.95
                ),
            ],
            tables: [],
            detectedData: [],
            fullText: "Name: Priya Sharma\nContact on 9876543210"
        )
    }

    @Test("Tier 2 fills what Tier 1 left unresolved")
    func fillsGaps() async {
        let resolver = StubResolver(answers: ["phone": "9876543210"])
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        let record = try! #require(result.records.first)
        #expect(record.value(forKey: "phone")?.normalized == "9876543210")
        #expect(record.value(forKey: "phone")?.source == .model)
    }

    @Test("A model value never draws a solid rule, however sure the model sounded")
    func modelValuesAreCapped() async {
        let resolver = StubResolver(answers: ["phone": "9876543210"])
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        let value = try! #require(result.records.first?.value(forKey: "phone"))
        #expect(value.confidence <= ModelConfidence.ceiling)
        #expect(value.band != .high, "a matched column is stronger evidence than an inference")
    }

    @Test("A model value carries no frame, because a transcript has no geometry")
    func modelValuesHaveNoFrame() async {
        let resolver = StubResolver(answers: ["phone": "9876543210"])
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        #expect(result.records.first?.value(forKey: "phone")?.frame == nil)
    }

    @Test("Tier 1's confident readings are never re-asked or overwritten")
    func tier1WinsWhereItWasConfident() async {
        // The stub would happily answer for name too, if it were asked.
        let resolver = StubResolver(answers: ["name": "WRONG", "phone": "9876543210"])
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        let record = try! #require(result.records.first)
        #expect(record.value(forKey: "name")?.normalized == "Priya Sharma")
        #expect(record.value(forKey: "name")?.source == .deterministic)

        let asked = await resolver.askedFor
        #expect(asked == ["phone"], "only the leftovers should be offered to the model")
    }

    @Test("Values the model returns are normalized like any other")
    func modelValuesAreNormalized() async {
        let template = TemplateSnapshot(
            id: UUID(), name: "Intake", mode: .record,
            dateConvention: .dayMonthYear, preferredDateFormat: nil,
            fields: [field("name", "Name"), field("amount", "Amount", .currency)],
            learnedHeaderAliases: []
        )
        let resolver = StubResolver(answers: ["amount": "₹1,440.00"])

        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: template)

        let value = try! #require(result.records.first?.value(forKey: "amount"))
        #expect(value.normalized == "1440.00")
        #expect(value.rawText == "₹1,440.00", "rawText keeps exactly what the model said")
    }

    @Test("A field the model omits stays unresolved rather than becoming empty-but-confident")
    func omittedFieldsStayUnresolved() async {
        let resolver = StubResolver(answers: [:])
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        let value = try! #require(result.records.first?.value(forKey: "phone"))
        #expect(value.source == .unresolved)
        #expect(value.confidence == 0)
    }

    @Test("An unavailable model degrades to Tier 1 output rather than an error")
    func unavailableModelDegrades() async {
        let resolver = StubResolver(
            failure: CarbonError.modelUnavailable(reason: .deviceNotEligible)
        )
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        #expect(result.records.count == 1)
        #expect(result.records[0].value(forKey: "name")?.normalized == "Priya Sharma")
        #expect(result.records[0].value(forKey: "phone")?.source == .unresolved)
        #expect(result.diagnostics.contains { $0.contains("tier 2 skipped") })
    }

    @Test("A timed-out model degrades the same way")
    func timeoutDegrades() async {
        let resolver = StubResolver(failure: CarbonError.modelTimedOut)
        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        #expect(result.records[0].value(forKey: "name")?.normalized == "Priya Sharma")
        #expect(result.diagnostics.contains { $0.contains("tier 2 skipped") })
    }

    @Test("With no resolver at all the ladder is simply Tier 1")
    func noResolver() async {
        let result = await LadderExtractor(resolver: nil)
            .extract(page: pageWithOnlyName(), template: recordTemplate())

        #expect(result.records[0].value(forKey: "name")?.normalized == "Priya Sharma")
        #expect(result.diagnostics.contains { $0.contains("tier 2 unavailable") })
    }

    @Test("Table mode never calls the model, and says why in the diagnostics")
    func tableModeSkipsTier2() async {
        let template = TemplateSnapshot(
            id: UUID(), name: "Register", mode: .table,
            dateConvention: .dayMonthYear, preferredDateFormat: nil,
            fields: [field("item", "Item"), field("amount", "Amount", .currency)],
            learnedHeaderAliases: []
        )
        let page = RecognizedPage(
            pageID: UUID(),
            blocks: [],
            tables: [
                RecognizedTable(
                    frame: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    rows: [
                        [cell("Item", 0, 0), cell("Amount", 0, 1)],
                        [cell("Sugar", 1, 0), cell("1440.00", 1, 1)],
                    ],
                    headerRowIndex: 0
                )
            ],
            detectedData: [],
            fullText: "Item Amount\nSugar 1440.00"
        )
        let resolver = StubResolver(answers: ["item": "WRONG"])

        let result = await LadderExtractor(resolver: resolver).extract(page: page, template: template)

        #expect(await resolver.callCount == 0, "a per-row model pass would blow the page budget")
        #expect(result.records[0].value(forKey: "item")?.normalized == "Sugar")
        #expect(result.diagnostics.contains { $0.contains("column matching") })
    }

    @Test("A fully resolved page does not wake the model at all")
    func noNeedNoCall() async {
        let template = TemplateSnapshot(
            id: UUID(), name: "Intake", mode: .record,
            dateConvention: .dayMonthYear, preferredDateFormat: nil,
            fields: [field("name", "Name")],
            learnedHeaderAliases: []
        )
        let resolver = StubResolver(answers: ["name": "WRONG"])

        let result = await LadderExtractor(resolver: resolver)
            .extract(page: pageWithOnlyName(), template: template)

        #expect(await resolver.callCount == 0)
        #expect(result.diagnostics.contains { $0.contains("not needed") })
    }

    @Test("The engine version records which ladder produced a record")
    func engineVersion() async {
        let result = await LadderExtractor(resolver: nil)
            .extract(page: pageWithOnlyName(), template: recordTemplate())
        #expect(result.engineVersion == LadderExtractor.engineVersion)
        #expect(result.engineVersion.contains("fm-text"))
    }

    private func cell(_ text: String, _ row: Int, _ column: Int) -> RecognizedCell {
        RecognizedCell(
            text: text,
            frame: NormalizedRect(
                x: 0.1 * Double(column), y: 0.1 * Double(row), width: 0.09, height: 0.05
            ),
            rowRange: row...row,
            columnRange: column...column,
            recognitionConfidence: 0.95
        )
    }
}

@Suite("Model availability")
struct ModelAvailabilityTests {
    @Test("Whatever this machine reports, the answer is one we can act on")
    func resolvesToAKnownState() async {
        // The model is unavailable in CI and on a simulator, and may be available on a
        // developer's Mac. Both are correct outcomes; what matters is that the app gets a
        // state it can degrade from rather than a crash or an unmapped case.
        let state = await ModelAvailability().state()

        switch state {
        case .available:
            #expect(state.isAvailable)
        case .unavailable(let reason):
            #expect(ModelUnavailableReason.allCases.contains(reason))
            #expect(!state.isAvailable)
        }
    }

    @Test("Only a still-downloading model is worth re-checking, so only it stays uncached")
    func transientStateIsNotCachedForever() async {
        let availability = ModelAvailability()
        let first = await availability.state()
        let second = await availability.state()
        #expect(first == second, "a stable answer must not change between calls")
    }
}
