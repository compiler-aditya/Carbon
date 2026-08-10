import Foundation
import SwiftData

extension CarbonStore {
    /// Deletes the photographs behind confirmed records, keeping the records themselves.
    ///
    /// The data is the point; the photograph is evidence you may no longer need once you have
    /// checked the row. Offered as a choice and never done automatically — silently deleting
    /// someone's source images is the wrong default, so Settings shows the number and lets
    /// them decide.
    ///
    /// Records still needing review keep their images, because those are exactly the ones
    /// where someone may want to look at the page again.
    ///
    /// - Returns: how many records had images removed.
    @discardableResult
    public func purgeImagesForConfirmedRecords(pageStore: any PageStoring) async throws -> Int {
        let confirmed = RecordStatus.confirmed.rawValue
        let descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.statusRaw == confirmed }
        )

        let records = try modelContext.fetch(descriptor)
        var purged = 0

        for record in records {
            let pages = record.pages ?? []
            guard !pages.isEmpty else { continue }

            let captures = Set(pages.map(\.captureID))
            for page in pages {
                modelContext.delete(page)
            }
            try modelContext.save()
            try await deleteUnreferencedCaptures(captures, pageStore: pageStore)
            purged += 1
        }

        try modelContext.save()
        return purged
    }

    /// How many confirmed records still have images on disk. Drives the Settings row, which
    /// says what will happen before it happens.
    public func confirmedRecordsWithImages() throws -> Int {
        let confirmed = RecordStatus.confirmed.rawValue
        let descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.statusRaw == confirmed }
        )
        return try modelContext.fetch(descriptor).count { !($0.pages ?? []).isEmpty }
    }
}
