import Foundation
import SwiftData

extension CarbonStore {
    /// Creates a template and its fields in one write.
    ///
    /// One transaction rather than create-then-add-fields, because a template with no fields
    /// is not a valid thing for the rest of the app to encounter, and a crash between the two
    /// writes would leave exactly that.
    @discardableResult
    public func createTemplate(
        name: String,
        subtitle: String = "",
        mode: TemplateMode = .record,
        dateConvention: DateConvention = .dayMonthYear,
        symbolName: String = "doc.text",
        fields: [NewFieldSpec] = [],
        createdAt: Date = .now
    ) throws -> UUID {
        let template = FormTemplate()
        template.name = name
        template.subtitle = subtitle
        template.mode = mode
        template.dateConvention = dateConvention
        template.symbolName = symbolName
        template.createdAt = createdAt
        template.updatedAt = createdAt
        modelContext.insert(template)

        var usedKeys: Set<String> = []
        for (index, spec) in fields.enumerated() {
            let definition = makeField(spec, order: index, existingKeys: &usedKeys)
            definition.template = template
            modelContext.insert(definition)
        }

        try modelContext.save()
        return template.id
    }

    /// Appends a field. Returns the frozen key it was given.
    @discardableResult
    public func addField(
        to templateID: UUID,
        spec: NewFieldSpec,
        at date: Date = .now
    ) throws -> String {
        guard let template = try template(withID: templateID) else { return "" }

        var usedKeys = Set(template.orderedFields.map(\.key))
        let nextOrder = (template.orderedFields.last?.order ?? -1) + 1

        let definition = makeField(spec, order: nextOrder, existingKeys: &usedKeys)
        definition.template = template
        modelContext.insert(definition)

        template.updatedAt = date
        try modelContext.save()
        return definition.key
    }

    /// Renames a field's label. The key does not move — that is the whole point of it.
    public func renameField(
        templateID: UUID,
        key: String,
        newLabel: String,
        at date: Date = .now
    ) throws {
        guard
            let template = try template(withID: templateID),
            let field = template.orderedFields.first(where: { $0.key == key })
        else { return }

        field.label = newLabel
        template.updatedAt = date
        try modelContext.save()
    }

    public func deleteField(templateID: UUID, key: String, at date: Date = .now) throws {
        guard
            let template = try template(withID: templateID),
            let field = template.orderedFields.first(where: { $0.key == key })
        else { return }

        modelContext.delete(field)
        template.updatedAt = date
        try modelContext.save()

        // Close the gap so order stays contiguous. Left sparse, a later insert-at-end can
        // collide with an existing order and the list becomes unstable.
        try reorderFields(templateID: templateID, orderedKeys: template.orderedFields.map(\.key))
    }

    /// Applies a new field order. Keys not named keep their relative position at the end.
    public func reorderFields(
        templateID: UUID,
        orderedKeys: [String],
        at date: Date = .now
    ) throws {
        guard let template = try template(withID: templateID) else { return }

        let byKey = Dictionary(uniqueKeysWithValues: template.orderedFields.map { ($0.key, $0) })
        var order = 0
        for key in orderedKeys {
            guard let field = byKey[key] else { continue }
            field.order = order
            order += 1
        }
        for field in template.orderedFields where !orderedKeys.contains(field.key) {
            field.order = order
            order += 1
        }

        template.updatedAt = date
        try modelContext.save()
    }

    public func updateTemplate(
        id: UUID,
        name: String? = nil,
        subtitle: String? = nil,
        mode: TemplateMode? = nil,
        dateConvention: DateConvention? = nil,
        symbolName: String? = nil,
        isArchived: Bool? = nil,
        at date: Date = .now
    ) throws {
        guard let template = try template(withID: id) else { return }

        if let name { template.name = name }
        if let subtitle { template.subtitle = subtitle }
        if let mode { template.mode = mode }
        if let dateConvention { template.dateConvention = dateConvention }
        if let symbolName { template.symbolName = symbolName }
        if let isArchived { template.isArchived = isArchived }
        template.updatedAt = date

        try modelContext.save()
    }

    /// Deletes a template, its records, and every photograph behind them.
    ///
    /// The record ids are collected *before* the delete, because afterwards there is nothing
    /// left to ask which files to remove.
    public func deleteTemplate(id: UUID, pageStore: any PageStoring) async throws {
        guard let template = try template(withID: id) else { return }

        let recordIDs = (template.records ?? []).map(\.id)
        modelContext.delete(template)
        try modelContext.save()

        for recordID in recordIDs {
            try await pageStore.deleteAll(recordID: recordID)
        }
    }

    // MARK: Reads

    public func templateSnapshot(id: UUID) throws -> TemplateSnapshot? {
        try template(withID: id)?.snapshot
    }

    public func templateSnapshots(includingArchived: Bool = false) throws -> [TemplateSnapshot] {
        let descriptor = FetchDescriptor<FormTemplate>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
            .filter { includingArchived || !$0.isArchived }
            .map(\.snapshot)
    }

    public func templateCount(includingArchived: Bool = false) throws -> Int {
        try templateSnapshots(includingArchived: includingArchived).count
    }

    // MARK: Shared

    private func makeField(
        _ spec: NewFieldSpec,
        order: Int,
        existingKeys: inout Set<String>
    ) -> FieldDefinition {
        let key = FieldKeyGenerator.uniqueKey(from: spec.label, existing: existingKeys)
        existingKeys.insert(key)

        let definition = FieldDefinition()
        definition.key = key
        definition.label = spec.label
        definition.order = order
        definition.type = spec.type
        definition.isRequired = spec.isRequired
        definition.choices = spec.choices
        definition.columnAliases = spec.columnAliases
        definition.currencyCode = spec.currencyCode
        definition.defaultValue = spec.defaultValue
        definition.unitSuffix = spec.unitSuffix
        return definition
    }
}
