import Foundation
import SwiftData

extension CarbonStore {
    /// Runs a dataset query.
    ///
    /// Template, status and date ordering go into the fetch descriptor, so the common case —
    /// scrolling a template's records newest-first — is a straight indexed read. Search and
    /// field-sorting happen after the fetch, because both depend on values that live on a
    /// to-many relationship and neither is expressible as a sort key.
    ///
    /// That is an honest trade at this size: a few hundred records filter in well under a
    /// frame. If a dataset ever grows past what this comfortably handles, the fix is a
    /// denormalised search column on `CaptureRecord`, not a cleverer predicate.
    public func records(matching query: RecordQuery) throws -> [RecordSnapshot] {
        let templateID = query.templateID
        var descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.template?.id == templateID },
            sortBy: [SortDescriptor(\.capturedAt, order: query.sort == .oldest ? .forward : .reverse)]
        )

        // A record still being captured is not part of the dataset yet.
        var snapshots = try modelContext.fetch(descriptor)
            .filter { $0.status != .draft }
            .map(\.snapshot)

        snapshots = snapshots.filter { matchesFilter($0, query.filter) }

        let search = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            snapshots = snapshots.filter { record in
                record.values.contains { $0.normalizedValue.localizedStandardContains(search) }
            }
        }

        if case .field(let key) = query.sort {
            // Numeric-aware, so an Amount column sorts 9 before 100 rather than after it.
            snapshots.sort {
                $0.exportValue(forKey: key)
                    .localizedStandardCompare($1.exportValue(forKey: key)) == .orderedAscending
            }
        }

        if query.offset > 0 {
            snapshots = Array(snapshots.dropFirst(query.offset))
        }
        if let limit = query.limit {
            snapshots = Array(snapshots.prefix(limit))
        }
        return snapshots
    }

    /// One record by id.
    public func recordSnapshot(id: UUID) throws -> RecordSnapshot? {
        try record(withID: id)?.snapshot
    }

    /// Counts for the filter chips. Cheap enough to recompute, and a stale count on a chip is
    /// worse than the work of keeping it right.
    public func recordCounts(templateID: UUID) throws -> [RecordFilter: Int] {
        let all = try records(matching: RecordQuery(templateID: templateID))
        return [
            .all: all.count,
            .needsReview: all.count { $0.status == .needsReview },
            .confirmed: all.count { $0.status == .confirmed },
        ]
    }

    /// Commits every record of a capture at once, after the user has looked at the grid.
    ///
    /// Table mode saves rows as `.needsReview` or `.confirmed` at write time; this is what
    /// the grid's Save button calls to mark the ones the user has now seen.
    public func confirmRecords(ids: [UUID]) throws {
        for id in ids {
            guard let record = try record(withID: id) else { continue }
            let stillDoubtful = (record.values ?? []).contains { $0.band == .needsReview }
            record.status = stillDoubtful ? .needsReview : .confirmed
        }
        try modelContext.save()
    }

    private func matchesFilter(_ record: RecordSnapshot, _ filter: RecordFilter) -> Bool {
        switch filter {
        case .all: true
        case .needsReview: record.status == .needsReview
        case .confirmed: record.status == .confirmed
        }
    }
}
