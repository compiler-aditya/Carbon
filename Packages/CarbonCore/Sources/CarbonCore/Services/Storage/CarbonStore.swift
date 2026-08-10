import Foundation
import SwiftData

/// All writes go through here, on a background context.
///
/// `@ModelActor` keeps the write path off the main thread while `@Query` keeps reads on it.
/// Every method takes and returns `Sendable` values — ids and snapshots — so no `@Model`
/// object ever crosses the boundary.
@ModelActor
public actor CarbonStore {
    /// Writes one page's extraction output as records.
    ///
    /// Conversion from `ExtractionResult` is explicit rather than a generic mapper, because
    /// this is where provenance is stamped on and where `rawText` is set for the only time in
    /// a value's life.
    ///
    /// - Returns: the ids of the records created, in page order.
    @discardableResult
    public func save(
        _ result: ExtractionResult,
        templateID: UUID,
        pages: [PageRef] = [],
        rawPageText: String = "",
        modelWasAvailable: Bool = false,
        capturedAt: Date = .now
    ) throws -> [UUID] {
        guard let template = try template(withID: templateID) else {
            throw CarbonError.noFieldsMatched
        }

        let definitionsByKey = Dictionary(
            uniqueKeysWithValues: template.orderedFields.map { ($0.key, $0) }
        )

        var createdIDs: [UUID] = []

        for extracted in result.records {
            let record = CaptureRecord()
            record.template = template
            record.capturedAt = capturedAt
            record.status = extracted.resolvedStatus
            record.sourceRowIndex = extracted.sourceRowIndex
            record.extractionDurationMs = result.durationMs
            record.engineVersion = result.engineVersion
            record.modelWasAvailable = modelWasAvailable
            record.rawPageText = rawPageText
            modelContext.insert(record)

            for extractedValue in extracted.values {
                let value = FieldValue()
                value.fieldDefinition = definitionsByKey[extractedValue.fieldKey]
                value.record = record
                // Set once, here, and never written again — not even by a correction.
                value.rawText = extractedValue.rawText
                value.normalizedValue = extractedValue.normalized
                value.confidence = extractedValue.confidence
                value.source = extractedValue.source
                value.frameJSON = extractedValue.frame?.jsonString
                modelContext.insert(value)
            }

            for page in pages {
                let asset = PageAsset()
                asset.record = record
                asset.pageIndex = page.pageIndex
                asset.fileName = page.fileName
                asset.createdAt = capturedAt
                modelContext.insert(asset)
            }

            createdIDs.append(record.id)
        }

        learn(result.aliasesToLearn, on: template)

        template.lastUsedAt = capturedAt
        template.updatedAt = capturedAt

        try modelContext.save()
        return createdIDs
    }

    /// Records a user's correction.
    ///
    /// The only supported way to change a stored value, because it is the only path that
    /// leaves `rawText` intact. The difference between the two is the accuracy dataset.
    public func applyCorrection(
        recordID: UUID,
        fieldKey: String,
        newValue: String,
        at date: Date = .now
    ) throws {
        guard let record = try record(withID: recordID) else { return }
        guard let value = record.value(forKey: fieldKey) else { return }

        value.applyCorrection(newValue, at: date)

        // A record whose remaining values are all fine is no longer waiting on anyone.
        let stillNeedsReview = (record.values ?? []).contains { $0.band == .needsReview }
        record.status = stillNeedsReview ? .needsReview : .confirmed

        try modelContext.save()
    }

    public func recordSnapshots(
        templateID: UUID,
        limit: Int? = nil,
        offset: Int = 0
    ) throws -> [RecordSnapshot] {
        var descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.template?.id == templateID },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchOffset = offset
        if let limit { descriptor.fetchLimit = limit }

        return try modelContext.fetch(descriptor).map(\.snapshot)
    }

    /// Deletes a record and the photographs behind it.
    ///
    /// The page store is a parameter rather than a stored dependency so the coupling is
    /// visible at every call site. SwiftData's cascade removes the `PageAsset` rows and will
    /// not touch the files — a delete that skips this leaves orphans in the container.
    public func deleteRecord(id: UUID, pageStore: any PageStoring) async throws {
        guard let record = try record(withID: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
        try await pageStore.deleteAll(recordID: id)
    }

    /// Records the header spellings a page taught us.
    ///
    /// The cheapest intelligent behaviour in the app: a column matched by fuzzy comparison
    /// this time becomes an exact match next time, with no model involved and no setting for
    /// the user to find. Aliases are compared case-insensitively so the same header in a
    /// different case does not accumulate twice.
    private func learn(_ aliases: [String: String], on template: FormTemplate) {
        guard !aliases.isEmpty else { return }

        for field in template.orderedFields {
            guard let observed = aliases[field.key] else { continue }
            let cleaned = observed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }

            let known = Set(
                (field.columnAliases + [field.label]).map { $0.lowercased() }
            )
            guard !known.contains(cleaned.lowercased()) else { continue }
            field.columnAliases.append(cleaned)
        }
    }

    // MARK: Lookups

    func template(withID id: UUID) throws -> FormTemplate? {
        var descriptor = FetchDescriptor<FormTemplate>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func record(withID id: UUID) throws -> CaptureRecord? {
        var descriptor = FetchDescriptor<CaptureRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
