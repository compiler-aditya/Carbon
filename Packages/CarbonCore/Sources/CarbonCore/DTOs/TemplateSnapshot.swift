import Foundation

/// An immutable projection of one `FormTemplate` and its fields.
///
/// This is what crosses into the extraction actor. `@Model` types are not `Sendable` and
/// must never make that trip.
public struct TemplateSnapshot: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let mode: TemplateMode
    public let dateConvention: DateConvention
    public let preferredDateFormat: String?

    /// Pre-sorted by the field's declared order, so no call site has to remember to sort.
    public let fields: [FieldSnapshot]

    /// Header strings seen on real scans of this form, accumulated from corrections.
    public let learnedHeaderAliases: [String]

    // Presentation and provenance the templates list needs — a card shows the symbol, the
    // subtitle, "142 records" and "2h ago". Carrying them here is what keeps that screen a
    // straight read of a snapshot rather than a reason to reach for the model.
    public let subtitle: String
    public let symbolName: String
    public let lastUsedAt: Date?
    public let recordCount: Int

    public init(
        id: UUID,
        name: String,
        mode: TemplateMode,
        dateConvention: DateConvention,
        preferredDateFormat: String?,
        fields: [FieldSnapshot],
        learnedHeaderAliases: [String],
        subtitle: String = "",
        symbolName: String = "doc.text",
        lastUsedAt: Date? = nil,
        recordCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.dateConvention = dateConvention
        self.preferredDateFormat = preferredDateFormat
        self.fields = fields
        self.learnedHeaderAliases = learnedHeaderAliases
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.lastUsedAt = lastUsedAt
        self.recordCount = recordCount
    }

    public func field(forKey key: String) -> FieldSnapshot? {
        fields.first { $0.key == key }
    }
}
