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

    public init(
        id: UUID,
        name: String,
        mode: TemplateMode,
        dateConvention: DateConvention,
        preferredDateFormat: String?,
        fields: [FieldSnapshot],
        learnedHeaderAliases: [String]
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.dateConvention = dateConvention
        self.preferredDateFormat = preferredDateFormat
        self.fields = fields
        self.learnedHeaderAliases = learnedHeaderAliases
    }

    public func field(forKey key: String) -> FieldSnapshot? {
        fields.first { $0.key == key }
    }
}
