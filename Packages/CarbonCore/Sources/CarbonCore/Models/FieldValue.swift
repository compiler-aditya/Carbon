import Foundation
import SwiftData

/// One extracted value. The most important entity in the model, because it is where the
/// app's honesty lives.
@Model
public final class FieldValue {
    public var id: UUID = UUID()

    /// Exactly what recognition produced, before normalization.
    ///
    /// **Never overwritten, not even when the user corrects the value.** The correction rate
    /// is the accuracy metric, and `rawText != normalizedValue` on an edited value says
    /// precisely what recognition got wrong. Overwrite this and a real evaluation set,
    /// harvested for free from ordinary use, is gone.
    public var rawText: String = ""

    /// Canonical form after normalization. Every read and every export uses this.
    ///
    /// Stored as a string rather than a typed union so the schema stays flat and CSV export
    /// is lossless; typed access comes from the field definition.
    public var normalizedValue: String = ""

    /// 0.0–1.0. Drives the confidence rule in the UI. 1.0 after a user edit.
    public var confidence: Double = 0
    public var sourceRaw: String = ExtractionSource.unresolved.rawValue

    public var wasEditedByUser: Bool = false
    public var editedAt: Date?

    /// Where on the page this was read from, normalised 0–1, as JSON. Enables zooming the
    /// source image to this value from the review screen — which is what proves the app is
    /// reading the actual page rather than inventing numbers.
    public var frameJSON: String?

    @Relationship public var record: CaptureRecord?
    @Relationship public var fieldDefinition: FieldDefinition?

    public init() {}

    public var source: ExtractionSource {
        get { ExtractionSource(rawValue: sourceRaw) ?? .unresolved }
        set { sourceRaw = newValue.rawValue }
    }

    public var band: ConfidenceBand {
        ConfidenceBand(confidence: confidence, source: source)
    }

    /// Applies a user's correction. The only supported way to change a value, because it is
    /// the only path that keeps `rawText` intact.
    public func applyCorrection(_ newValue: String, at date: Date = .now) {
        normalizedValue = newValue
        confidence = 1.0
        source = .userEntered
        wasEditedByUser = true
        editedAt = date
    }
}
