import Foundation
import SwiftData

/// One completed export. Cheap to keep, and it lets Settings show "12 exports, 486 records",
/// which makes the app feel like it has a history rather than a blank slate every launch.
@Model
public final class ExportLog {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var templateID: UUID?
    public var formatRaw: String = ExportFormat.csv.rawValue
    public var recordCount: Int = 0
    public var fileName: String = ""

    public init() {}

    public var format: ExportFormat {
        get { ExportFormat(rawValue: formatRaw) ?? .csv }
        set { formatRaw = newValue.rawValue }
    }
}
