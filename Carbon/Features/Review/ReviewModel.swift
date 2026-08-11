import CarbonCore
import Foundation
import Observation

/// Backs the review screen for one captured record.
@MainActor
@Observable
final class ReviewModel {
    private(set) var record: RecordSnapshot?
    private(set) var isSaving = false

    let template: TemplateSnapshot
    private let store: CarbonStore
    private let recordID: UUID

    init(store: CarbonStore, template: TemplateSnapshot, recordID: UUID) {
        self.store = store
        self.template = template
        self.recordID = recordID
    }

    /// Fields needing attention sort to the top, and the first is what the user lands on.
    ///
    /// Sorting by doubt rather than by declared order is the whole point of the screen: the
    /// user is here to resolve what Carbon could not, not to re-read what it got right.
    var orderedFields: [FieldSnapshot] {
        guard let record else { return template.fields }
        return template.fields.sorted { lhs, rhs in
            let lhsDoubtful = band(for: lhs) == .needsReview
            let rhsDoubtful = band(for: rhs) == .needsReview
            if lhsDoubtful != rhsDoubtful { return lhsDoubtful }
            return declaredIndex(lhs) < declaredIndex(rhs)
        }
        .map { $0 }
    }

    var needsReviewCount: Int {
        template.fields.count { band(for: $0) == .needsReview }
    }

    func value(for field: FieldSnapshot) -> FieldValueSnapshot? {
        record?.value(forKey: field.key)
    }

    func band(for field: FieldSnapshot) -> ConfidenceBand {
        value(for: field)?.band ?? .needsReview
    }

    func load() async {
        record = try? await store.recordSnapshot(id: recordID)
    }

    func correct(field: FieldSnapshot, to newValue: String) async {
        guard value(for: field)?.normalizedValue != newValue else { return }
        isSaving = true
        defer { isSaving = false }

        try? await store.applyCorrection(
            recordID: recordID, fieldKey: field.key, newValue: newValue
        )
        await load()
    }

    private func declaredIndex(_ field: FieldSnapshot) -> Int {
        template.fields.firstIndex { $0.key == field.key } ?? 0
    }
}
