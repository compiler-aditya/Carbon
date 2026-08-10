import Foundation
import SwiftData

/// A pointer to one scanned page on disk. Holds the filename, never the bytes.
@Model
public final class PageAsset {
    public var id: UUID = UUID()
    public var pageIndex: Int = 0

    /// Which capture produced this page. Several records share one when a table page yields
    /// many rows, which is why the file is keyed by this and not by a record id.
    public var captureID: UUID = UUID()

    /// Relative to `Application Support/Scans/<captureID>/`.
    public var fileName: String = ""

    public var pixelWidth: Int = 0
    public var pixelHeight: Int = 0
    public var byteCount: Int = 0
    public var createdAt: Date = Date()

    @Relationship public var record: CaptureRecord?

    public init() {}
}
