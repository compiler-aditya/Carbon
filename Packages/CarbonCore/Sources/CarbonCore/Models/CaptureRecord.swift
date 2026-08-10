import Foundation
import SwiftData

/// One row of the dataset: the values read from one form, or from one row of one form.
@Model
public final class CaptureRecord {
    #Index<CaptureRecord>([\.capturedAt], [\.statusRaw])

    public var id: UUID = UUID()

    public var capturedAt: Date = Date()
    public var statusRaw: String = RecordStatus.draft.rawValue

    /// Which table row on the source page this came from. Nil in record mode.
    public var sourceRowIndex: Int?
    public var sourcePageIndex: Int = 0

    /// Provenance. This is what makes the corpus harness and the README accuracy numbers
    /// possible at all.
    public var extractionDurationMs: Int = 0
    public var engineVersion: String = ""
    public var modelWasAvailable: Bool = false

    /// Full reading-order text of the source page, kept for debugging and re-extraction.
    /// Purgeable from Settings.
    public var rawPageText: String = ""

    public var notes: String = ""

    @Relationship public var template: FormTemplate?

    @Relationship(deleteRule: .cascade, inverse: \FieldValue.record)
    public var values: [FieldValue]? = []

    @Relationship(deleteRule: .cascade, inverse: \PageAsset.record)
    public var pages: [PageAsset]? = []

    public init() {}

    public var status: RecordStatus {
        get { RecordStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    public func value(forKey key: String) -> FieldValue? {
        (values ?? []).first { $0.fieldDefinition?.key == key }
    }
}
