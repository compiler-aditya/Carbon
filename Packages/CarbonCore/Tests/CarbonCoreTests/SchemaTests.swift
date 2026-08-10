import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("SwiftData schema")
@MainActor
struct SchemaTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("The v1 schema builds a container")
    func schemaLoads() throws {
        let container = try makeContainer()
        #expect(container.schema.entities.count == CarbonSchemaV1.models.count)
    }

    @Test("The schema registers every model, so nothing is silently unpersisted")
    func schemaIsComplete() {
        #expect(CarbonSchemaV1.models.count == 7)
        #expect(CarbonSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test("Fields come back in declared order regardless of insertion order")
    func fieldsAreOrdered() throws {
        let context = ModelContext(try makeContainer())
        let template = FormTemplate()
        template.name = "Daily Register"
        context.insert(template)

        for (index, label) in ["Amount", "Date", "Item"].enumerated() {
            let field = FieldDefinition()
            field.label = label
            field.key = label.lowercased()
            // Deliberately not in insertion order.
            field.order = [2, 0, 1][index]
            field.template = template
            context.insert(field)
        }
        try context.save()

        #expect(template.orderedFields.map(\.label) == ["Date", "Item", "Amount"])
    }

    @Test("Deleting a template cascades to its fields and records")
    func cascadeDelete() throws {
        let context = ModelContext(try makeContainer())
        let template = FormTemplate()
        context.insert(template)

        let field = FieldDefinition()
        field.key = "qty"
        field.template = template
        context.insert(field)

        let record = CaptureRecord()
        record.template = template
        context.insert(record)
        try context.save()

        context.delete(template)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<FieldDefinition>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CaptureRecord>()).isEmpty)
    }

    @Test("Correcting a value never overwrites what recognition read")
    func correctionPreservesRawText() throws {
        let context = ModelContext(try makeContainer())
        let value = FieldValue()
        value.rawText = "l4"          // recognition misread a 1 as a lowercase L
        value.normalizedValue = "l4"
        value.confidence = 0.4
        value.source = .deterministic
        context.insert(value)

        value.applyCorrection("14")
        try context.save()

        #expect(value.rawText == "l4", "rawText is the accuracy dataset and must survive")
        #expect(value.normalizedValue == "14")
        #expect(value.confidence == 1.0)
        #expect(value.source == .userEntered)
        #expect(value.wasEditedByUser)
        #expect(value.editedAt != nil)
        #expect(value.band == .high)
    }

    @Test("Enum accessors round-trip through their stored raw values")
    func enumRoundTrip() throws {
        let context = ModelContext(try makeContainer())
        let template = FormTemplate()
        context.insert(template)

        template.mode = .table
        template.dateConvention = .yearMonthDay
        try context.save()

        #expect(template.modeRaw == "table")
        #expect(template.dateConventionRaw == "yearMonthDay")
        #expect(template.mode == .table)
    }

    @Test("An unrecognised stored raw value falls back rather than crashing")
    func unknownRawValueFallsBack() throws {
        let context = ModelContext(try makeContainer())
        let template = FormTemplate()
        context.insert(template)

        // Simulates a store written by a future version that added a case.
        template.modeRaw = "somethingAddedLater"
        #expect(template.mode == .record)
    }

    @Test("Aliases are deduped and lowercased across label, declared and learned")
    func aliasMerging() {
        let field = FieldDefinition()
        field.label = "Amount"
        field.columnAliases = ["amount", "AMT", " Total "]

        let aliases = field.matchingAliases(learned: ["amt", "Value"])
        #expect(aliases == ["amount", "amt", "total", "value"])
    }
}
