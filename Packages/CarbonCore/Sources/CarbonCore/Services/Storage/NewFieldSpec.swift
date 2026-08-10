import Foundation

/// What the editor hands the store to create one field.
///
/// Deliberately has no `key`: keys are the store's business, generated from the label once
/// and then frozen. Letting a caller supply one is how two fields end up sharing a CSV column.
public struct NewFieldSpec: Sendable, Hashable {
    public let label: String
    public let type: FieldType
    public let isRequired: Bool
    public let choices: [String]
    public let columnAliases: [String]
    public let currencyCode: String
    public let defaultValue: String
    public let unitSuffix: String

    public init(
        label: String,
        type: FieldType = .text,
        isRequired: Bool = false,
        choices: [String] = [],
        columnAliases: [String] = [],
        currencyCode: String = "",
        defaultValue: String = "",
        unitSuffix: String = ""
    ) {
        self.label = label
        self.type = type
        self.isRequired = isRequired
        self.choices = choices
        self.columnAliases = columnAliases
        self.currencyCode = currencyCode
        self.defaultValue = defaultValue
        self.unitSuffix = unitSuffix
    }
}
