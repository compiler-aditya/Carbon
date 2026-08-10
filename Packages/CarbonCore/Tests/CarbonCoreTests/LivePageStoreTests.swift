import CoreGraphics
import Foundation
import Testing

@testable import CarbonCore

@Suite("Page storage")
struct LivePageStoreTests {
    /// A real store rooted in a throwaway directory, cleaned up by the caller.
    private func makeStore() throws -> (LivePageStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "carbon-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (try LivePageStore(rootDirectory: root), root)
    }

    private func makeImage(width: Int = 64, height: Int = 48) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 0.9, green: 0.9, blue: 0.85, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @Test("A page round-trips through disk at its original dimensions")
    func roundTrip() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let captureID = UUID()
        let ref = try await store.persist(makeImage(), captureID: captureID, pageIndex: 0)

        #expect(ref.relativePath == "\(captureID.uuidString)/0.jpg")

        let loaded = try await store.load(ref)
        #expect(loaded.width == 64)
        #expect(loaded.height == 48)
    }

    @Test("Pages land in one directory per capture")
    func directoryPerCapture() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let captureID = UUID()
        for index in 0..<3 {
            try await store.persist(makeImage(), captureID: captureID, pageIndex: index)
        }

        let directory = root.appending(path: captureID.uuidString)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path())
        #expect(Set(files) == ["0.jpg", "1.jpg", "2.jpg"])
    }

    @Test("Deleting a capture removes its files, not just its rows")
    func deleteAllRemovesFiles() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let doomed = UUID()
        let kept = UUID()
        try await store.persist(makeImage(), captureID: doomed, pageIndex: 0)
        try await store.persist(makeImage(), captureID: doomed, pageIndex: 1)
        try await store.persist(makeImage(), captureID: kept, pageIndex: 0)

        try await store.deleteAll(captureID: doomed)

        #expect(!FileManager.default.fileExists(atPath: root.appending(path: doomed.uuidString).path()))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: kept.uuidString).path()))
    }

    @Test("Deleting one page leaves its siblings alone")
    func deleteSinglePage() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let captureID = UUID()
        let first = try await store.persist(makeImage(), captureID: captureID, pageIndex: 0)
        try await store.persist(makeImage(), captureID: captureID, pageIndex: 1)

        try await store.delete(first)

        let files = try FileManager.default.contentsOfDirectory(
            atPath: root.appending(path: captureID.uuidString).path()
        )
        #expect(files == ["1.jpg"])
    }

    @Test("Loading a page that was never written throws rather than returning something empty")
    func loadMissing() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        await #expect(throws: CarbonError.self) {
            try await store.load(PageRef(captureID: UUID(), pageIndex: 0))
        }
    }

    @Test("Total size reflects what is actually on disk")
    func totalBytes() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let empty = try await store.totalBytes()
        #expect(empty == 0)

        try await store.persist(makeImage(width: 400, height: 300), captureID: UUID(), pageIndex: 0)
        let afterOne = try await store.totalBytes()
        #expect(afterOne > 0)

        try await store.persist(makeImage(width: 400, height: 300), captureID: UUID(), pageIndex: 0)
        #expect(try await store.totalBytes() > afterOne)
    }

    @Test("The scans directory is excluded from backup")
    func excludedFromBackup() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try await store.persist(makeImage(), captureID: UUID(), pageIndex: 0)

        let excluded = try root.resourceValues(forKeys: [.isExcludedFromBackupKey])
            .isExcludedFromBackup
        #expect(excluded == true)
    }
}
