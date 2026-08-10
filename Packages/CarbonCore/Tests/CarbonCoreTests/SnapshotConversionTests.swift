import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("Model to snapshot conversion")
@MainActor
struct SnapshotConversionTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(
            try ModelContainer(
                for: Schema.carbon,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
    }

    @Test("A template projects its fields in order, with learned aliases merged in")
    func templateSnapshot() throws {
        let context = try makeContext()
        let template = FormTemplate()
        template.name = "Daily Register"
        template.mode = .table
        template.dateConvention = .dayMonthYear
        template.learnedHeaderAliases = ["Rate/unit"]
        context.insert(template)

        let quantity = FieldDefinition()
        quantity.key = "quantity"
        quantity.label = "Qty"
        quantity.order = 1
        quantity.type = .integer
        quantity.template = template
        context.insert(quantity)

        let date = FieldDefinition()
        date.key = "date"
        date.label = "Date"
        date.order = 0
        date.type = .date
        date.template = template
        context.insert(date)
        try context.save()

        let snapshot = template.snapshot
        #expect(snapshot.fields.map(\.key) == ["date", "quantity"])
        #expect(snapshot.mode == .table)
        #expect(snapshot.field(forKey: "quantity")?.type == .integer)
        // Learned aliases reach each field, which is what makes Tier 1 improve with use.
        #expect(snapshot.field(forKey: "date")?.aliases.contains("rate/unit") == true)
    }

    @Test("Empty stored attributes become nil rather than empty strings")
    func emptyAttributesBecomeNil() throws {
        let context = try makeContext()
        let template = FormTemplate()
        context.insert(template)
        let field = FieldDefinition()
        field.key = "note"
        field.template = template
        context.insert(field)
        try context.save()

        let snapshot = template.snapshot
        #expect(snapshot.preferredDateFormat == nil)
        #expect(snapshot.fields.first?.currencyCode == nil)
        #expect(snapshot.fields.first?.defaultValue == nil)
        #expect(snapshot.fields.first?.validationPattern == nil)
    }

    @Test("Frames round-trip through their stored JSON")
    func frameRoundTrip() throws {
        let context = try makeContext()
        let value = FieldValue()
        let frame = NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        value.frameJSON = frame.jsonString
        context.insert(value)

        #expect(value.snapshot.frame == frame)
    }

    @Test("A corrupt stored frame is dropped, not fatal")
    func corruptFrameIsDropped() throws {
        let context = try makeContext()
        let value = FieldValue()
        value.rawText = "14"
        value.frameJSON = "{not json"
        context.insert(value)

        let snapshot = value.snapshot
        #expect(snapshot.frame == nil)
        #expect(snapshot.rawText == "14", "the value survives a broken zoom target")
    }

    @Test("A record projects every value with its field key attached")
    func recordSnapshot() throws {
        let context = try makeContext()
        let template = FormTemplate()
        context.insert(template)

        let field = FieldDefinition()
        field.key = "amount"
        field.template = template
        context.insert(field)

        let record = CaptureRecord()
        record.template = template
        record.status = .needsReview
        context.insert(record)

        let value = FieldValue()
        value.rawText = "1,200"
        value.normalizedValue = "1200"
        value.confidence = 0.9
        value.source = .deterministic
        value.fieldDefinition = field
        value.record = record
        context.insert(value)
        try context.save()

        let snapshot = record.snapshot
        #expect(snapshot.status == .needsReview)
        #expect(snapshot.exportValue(forKey: "amount") == "1200")
        #expect(snapshot.value(forKey: "amount")?.rawText == "1,200")
    }
}
