import Foundation

/// What Settings shows about export history: "12 exports, 486 records".
///
/// Cheap to keep and it makes the app feel like it has a past, rather than resetting to a
/// blank slate every launch.
public struct ExportSummary: Sendable, Hashable {
    public let exportCount: Int
    public let recordCount: Int
    public let lastExportedAt: Date?

    public init(exportCount: Int, recordCount: Int, lastExportedAt: Date?) {
        self.exportCount = exportCount
        self.recordCount = recordCount
        self.lastExportedAt = lastExportedAt
    }

    public static let empty = ExportSummary(exportCount: 0, recordCount: 0, lastExportedAt: nil)
}
