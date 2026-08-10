import Foundation

/// An immutable projection of one `CaptureRecord`. What the exporter and the corpus harness
/// are handed.
public struct RecordSnapshot: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let capturedAt: Date
    public let status: RecordStatus

    /// Which table row this came from, in table mode. Nil in record mode.
    public let sourceRowIndex: Int?

    public let values: [FieldValueSnapshot]

    // Provenance. The corpus harness compares runs across a week of changes, which it can
    // only do if each record remembers which engine produced it and how long it took.
    public let engineVersion: String
    public let extractionDurationMs: Int
    public let modelWasAvailable: Bool

    public init(
        id: UUID,
        capturedAt: Date,
        status: RecordStatus,
        sourceRowIndex: Int?,
        values: [FieldValueSnapshot],
        engineVersion: String = "",
        extractionDurationMs: Int = 0,
        modelWasAvailable: Bool = false
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.status = status
        self.sourceRowIndex = sourceRowIndex
        self.values = values
        self.engineVersion = engineVersion
        self.extractionDurationMs = extractionDurationMs
        self.modelWasAvailable = modelWasAvailable
    }

    public func value(forKey key: String) -> FieldValueSnapshot? {
        values.first { $0.fieldKey == key }
    }

    /// The exported cell for a field. A field with no stored value exports as empty rather
    /// than being omitted, so every row in the CSV has the same number of columns.
    public func exportValue(forKey key: String) -> String {
        value(forKey: key)?.normalizedValue ?? ""
    }

    public var needsReview: Bool {
        values.contains { $0.band == .needsReview }
    }
}
