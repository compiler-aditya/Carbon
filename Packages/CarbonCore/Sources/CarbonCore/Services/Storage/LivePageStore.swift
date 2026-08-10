import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes scanned pages to `Application Support/Scans/<recordUUID>/<pageIndex>.jpg`.
///
/// Files rather than SwiftData blobs: trivial to inspect while debugging, trivial to purge,
/// and they keep the store small enough that the dataset list scrolls without care.
public actor LivePageStore: PageStoring {
    private let rootURL: URL
    private var hasPreparedRoot = false

    /// - Parameter rootDirectory: overridden in tests. Defaults to the app container.
    public init(rootDirectory: URL? = nil) throws {
        if let rootDirectory {
            rootURL = rootDirectory
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            rootURL = appSupport.appending(path: PageRef.directoryName, directoryHint: .isDirectory)
        }
    }

    @discardableResult
    public func persist(_ image: CGImage, recordID: UUID, pageIndex: Int) async throws -> PageRef {
        try prepareRootIfNeeded()

        let ref = PageRef(recordID: recordID, pageIndex: pageIndex)
        let url = fileURL(for: ref)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
            )
        else {
            throw CarbonError.pageWriteFailed(underlying: "could not open \(ref.relativePath)")
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: PageRef.compressionQuality] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            throw CarbonError.pageWriteFailed(underlying: "could not write \(ref.relativePath)")
        }
        return ref
    }

    public func load(_ ref: PageRef) async throws -> CGImage {
        let url = fileURL(for: ref)
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw CarbonError.pageWriteFailed(underlying: "could not read \(ref.relativePath)")
        }
        return image
    }

    public func delete(_ ref: PageRef) async throws {
        try? FileManager.default.removeItem(at: fileURL(for: ref))
    }

    /// Removes a record's whole directory.
    ///
    /// SwiftData's cascade delete removes the `PageAsset` rows and **will not touch these
    /// files**. Every record delete has to come through here or the container fills with
    /// orphaned photographs — the most common source of leaked data in apps of this shape.
    public func deleteAll(recordID: UUID) async throws {
        let directory = rootURL.appending(path: recordID.uuidString, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
    }

    public func totalBytes() async throws -> Int {
        Self.directorySize(at: rootURL)
    }

    /// Synchronous on purpose: `FileManager`'s enumerator cannot be iterated from an async
    /// context, and walking a directory is fast enough that hopping off the actor would cost
    /// more than it saves.
    private nonisolated static func directorySize(at url: URL) -> Int {
        guard
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        else { return 0 }

        var total = 0
        for case let fileURL as URL in enumerator {
            total += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }

    private func fileURL(for ref: PageRef) -> URL {
        rootURL.appending(path: ref.relativePath)
    }

    /// Creates the scans directory and excludes it from backup.
    ///
    /// Source photographs are large and reproducible from nothing — pushing them into a
    /// user's iCloud backup by default is a decision they should get to make, so Settings
    /// carries a toggle and the default is off.
    private func prepareRootIfNeeded() throws {
        guard !hasPreparedRoot else { return }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        var url = rootURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)

        hasPreparedRoot = true
    }
}
