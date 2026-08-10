import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import CarbonCore

@Suite("Storage maintenance")
struct MaintenanceTests {
    private func makeStore() throws -> CarbonStore {
        let container = try ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CarbonStore(modelContainer: container)
    }

    private func makePageStore() throws -> (LivePageStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "carbon-maint-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (try LivePageStore(rootDirectory: root), root)
    }

    private func makeImage() -> CGImage {
        let context = CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    /// Saves one record at the given confidence, with a page on disk.
    private func seed(
        _ store: CarbonStore,
        _ pageStore: LivePageStore,
        templateID: UUID,
        confidence: Double
    ) async throws -> UUID {
        let ref = try await pageStore.persist(makeImage(), captureID: UUID(), pageIndex: 0)

        let ids = try await store.save(
            ExtractionResult(
                records: [
                    ExtractedRecord(
                        sourceRowIndex: 0,
                        values: [
                            ExtractedValue(
                                fieldKey: "item", rawText: "Sugar", normalized: "Sugar",
                                confidence: confidence, source: .deterministic, frame: nil
                            )
                        ]
                    )
                ],
                pageID: UUID(), durationMs: 1, engineVersion: "test", diagnostics: []
            ),
            templateID: templateID,
            pages: [ref]
        )
        return ids[0]
    }

    @Test("Purging removes images for confirmed records and keeps their data")
    func purgeKeepsData() async throws {
        let store = try makeStore()
        let (pageStore, root) = try makePageStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let templateID = try await store.createTemplate(
            name: "Register", fields: [NewFieldSpec(label: "Item")]
        )
        try await seed(store, pageStore, templateID: templateID, confidence: 0.95)

        #expect(try await store.confirmedRecordsWithImages() == 1)
        #expect(try await pageStore.totalBytes() > 0)

        let purged = try await store.purgeImagesForConfirmedRecords(pageStore: pageStore)

        #expect(purged == 1)
        #expect(try await pageStore.totalBytes() == 0, "the photographs are gone")

        // The data is the point. It must survive.
        let records = try await store.records(matching: RecordQuery(templateID: templateID))
        #expect(records.count == 1)
        #expect(records[0].exportValue(forKey: "item") == "Sugar")
    }

    @Test("A record still needing review keeps its photograph")
    func doubtfulRecordsKeepImages() async throws {
        let store = try makeStore()
        let (pageStore, root) = try makePageStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let templateID = try await store.createTemplate(
            name: "Register", fields: [NewFieldSpec(label: "Item")]
        )
        try await seed(store, pageStore, templateID: templateID, confidence: 0.95)
        try await seed(store, pageStore, templateID: templateID, confidence: 0.30)

        let bytesBefore = try await pageStore.totalBytes()
        let purged = try await store.purgeImagesForConfirmedRecords(pageStore: pageStore)

        #expect(purged == 1, "only the confirmed record was purged")
        // Exactly the pages someone might want to look at again are the ones kept.
        let bytesAfter = try await pageStore.totalBytes()
        #expect(bytesAfter > 0)
        #expect(bytesAfter < bytesBefore)
    }

    @Test("Purging twice is harmless")
    func purgeIsIdempotent() async throws {
        let store = try makeStore()
        let (pageStore, root) = try makePageStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let templateID = try await store.createTemplate(
            name: "Register", fields: [NewFieldSpec(label: "Item")]
        )
        try await seed(store, pageStore, templateID: templateID, confidence: 0.95)

        #expect(try await store.purgeImagesForConfirmedRecords(pageStore: pageStore) == 1)
        #expect(try await store.purgeImagesForConfirmedRecords(pageStore: pageStore) == 0)
        #expect(try await store.confirmedRecordsWithImages() == 0)
    }

    @Test("Nothing to purge reports nothing rather than failing")
    func emptyPurge() async throws {
        let store = try makeStore()
        let (pageStore, root) = try makePageStore()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try await store.purgeImagesForConfirmedRecords(pageStore: pageStore) == 0)
        #expect(try await store.confirmedRecordsWithImages() == 0)
    }
}
