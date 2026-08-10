import Foundation

/// An immutable projection of one `FieldDefinition`.
///
/// Services never see the `@Model`. They see this.
public struct FieldSnapshot: Sendable, Identifiable, Hashable {
    public let id: UUID

    /// The frozen machine key. CSV column key and App Intent parameter name.
    public let key: String

    /// User-facing and editable. Presentation only — never a contract.
    public let label: String

    public let type: FieldType
    public let isRequired: Bool

    /// Label plus declared column aliases plus anything learned from corrections,
    /// deduped and lowercased. Tier 1 matches header cells against this set.
    public let aliases: [String]

    public let choices: [String]
    public let defaultValue: String?
    public let currencyCode: String?
    public let validationPattern: String?

    /// Where this field's value was found last time. A positional prior for record-mode
    /// matching; nil until the first successful read.
    public let lastKnownFrame: NormalizedRect?

    public init(
        id: UUID,
        key: String,
        label: String,
        type: FieldType,
        isRequired: Bool,
        aliases: [String],
        choices: [String],
        defaultValue: String?,
        currencyCode: String?,
        validationPattern: String?,
        lastKnownFrame: NormalizedRect?
    ) {
        self.id = id
        self.key = key
        self.label = label
        self.type = type
        self.isRequired = isRequired
        self.aliases = aliases
        self.choices = choices
        self.defaultValue = defaultValue
        self.currencyCode = currencyCode
        self.validationPattern = validationPattern
        self.lastKnownFrame = lastKnownFrame
    }
}
