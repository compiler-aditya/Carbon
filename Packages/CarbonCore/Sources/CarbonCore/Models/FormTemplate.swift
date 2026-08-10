import Foundation
import SwiftData

/// The organising concept of the whole product. Everything hangs off a template.
///
/// The schema is CloudKit-*compatible* even though v1 has no sync: no unique constraints,
/// every relationship optional, every non-optional attribute defaulted. Five minutes now,
/// a two-day rescue avoided later.
@Model
public final class FormTemplate {
    public var id: UUID = UUID()

    public var name: String = ""

    /// "Daily sales register" — shown under the name.
    public var subtitle: String = ""

    public var symbolName: String = "doc.text"

    /// Empty means use the app accent.
    public var accentHex: String = ""

    /// Enums are persisted as raw strings with a computed accessor rather than stored as
    /// `RawRepresentable`. Bulletproof across migrations and it avoids a class of predicate
    /// problems that only show up once there is data.
    public var modeRaw: String = TemplateMode.record.rawValue
    public var dateConventionRaw: String = DateConvention.dayMonthYear.rawValue

    /// Optional format hint, tried before the standard list.
    public var preferredDateFormat: String = ""

    /// Header strings observed on real scans of this form, accumulated as users correct
    /// mismatches. Tier 1 matching improves with use, with no model involved — the cheapest
    /// intelligent behaviour in the app.
    public var learnedHeaderAliases: [String] = []

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var lastUsedAt: Date?
    public var isArchived: Bool = false

    /// Reference scan captured when the template was created. Shown in the editor as a guide.
    public var referencePageRef: String?

    @Relationship(deleteRule: .cascade, inverse: \FieldDefinition.template)
    public var fields: [FieldDefinition]? = []

    @Relationship(deleteRule: .cascade, inverse: \CaptureRecord.template)
    public var records: [CaptureRecord]? = []

    public init() {}

    public var mode: TemplateMode {
        get { TemplateMode(rawValue: modeRaw) ?? .record }
        set { modeRaw = newValue.rawValue }
    }

    public var dateConvention: DateConvention {
        get { DateConvention(rawValue: dateConventionRaw) ?? .dayMonthYear }
        set { dateConventionRaw = newValue.rawValue }
    }

    /// Fields in their declared order. Every call site reads this instead of unwrapping and
    /// sorting, so ordering is decided once.
    public var orderedFields: [FieldDefinition] {
        (fields ?? []).sorted { $0.order < $1.order }
    }

    public var recordCount: Int { records?.count ?? 0 }
}
