import Foundation

/// Where one scanned page lives on disk.
///
/// The store holds a filename; the bytes live in Application Support. Files rather than
/// SwiftData blobs because they are trivial to inspect while debugging, trivial to purge, and
/// they keep the store small enough that the dataset list scrolls without care.
public struct PageRef: Sendable, Hashable, Codable {
    public let recordID: UUID
    public let pageIndex: Int

    public init(recordID: UUID, pageIndex: Int) {
        self.recordID = recordID
        self.pageIndex = pageIndex
    }

    public var fileName: String { "\(pageIndex).jpg" }

    /// Relative to the scans directory: `<recordUUID>/<pageIndex>.jpg`.
    ///
    /// One directory per record, so deleting a record is one directory removal. SwiftData's
    /// cascade delete removes the rows but will not touch these files — the delete path has
    /// to do it explicitly, and that is the single most common source of orphaned data in
    /// apps shaped like this one.
    public var relativePath: String { "\(recordID.uuidString)/\(fileName)" }

    public static let directoryName = "Scans"

    /// JPEG quality used for every persisted page. High enough that recognition is unaffected,
    /// low enough that a thousand-record dataset does not fill the device.
    public static let compressionQuality = 0.8
}
