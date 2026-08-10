import Foundation

/// Where one scanned page lives on disk.
///
/// The store holds a filename; the bytes live in Application Support. Files rather than
/// SwiftData blobs because they are trivial to inspect while debugging, trivial to purge, and
/// they keep the store small enough that the dataset list scrolls without care.
public struct PageRef: Sendable, Hashable, Codable {
    /// Identifies the **capture**, not a record.
    ///
    /// One photograph of a register produces many records, and they all point at the same
    /// image. Keying the directory by record id could never line up: the records do not exist
    /// yet when the page is persisted, and there are several of them when they do.
    public let captureID: UUID
    public let pageIndex: Int

    public init(captureID: UUID, pageIndex: Int) {
        self.captureID = captureID
        self.pageIndex = pageIndex
    }

    public var fileName: String { "\(pageIndex).jpg" }

    /// Relative to the scans directory: `<captureUUID>/<pageIndex>.jpg`.
    ///
    /// One directory per capture. SwiftData's cascade delete removes the rows but will not
    /// touch these files, and a file is shared by every record the page produced — so the
    /// delete path removes it only once nothing references it any more. This is the single
    /// most common source of orphaned data in apps shaped like this one.
    public var relativePath: String { "\(captureID.uuidString)/\(fileName)" }

    public static let directoryName = "Scans"

    /// JPEG quality used for every persisted page. High enough that recognition is unaffected,
    /// low enough that a thousand-record dataset does not fill the device.
    public static let compressionQuality = 0.8
}
