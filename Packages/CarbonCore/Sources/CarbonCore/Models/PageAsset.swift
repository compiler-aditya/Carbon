import Foundation
import SwiftData

/// A pointer to one scanned page on disk. Holds the filename, never the bytes.
@Model
public final class PageAsset {
    public var id: UUID = UUID()
    public var pageIndex: Int = 0

    /// Relative to `Application Support/Scans/`.
    public var fileName: String = ""

    public var pixelWidth: Int = 0
    public var pixelHeight: Int = 0
    public var byteCount: Int = 0
    public var createdAt: Date = Date()

    @Relationship public var record: CaptureRecord?

    public init() {}
}
