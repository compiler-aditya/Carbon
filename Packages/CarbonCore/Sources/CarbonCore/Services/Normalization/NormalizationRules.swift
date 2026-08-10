/// Everything normalization needs to know about one field, flattened out of the template.
///
/// Passed explicitly rather than read from a snapshot so the normalization functions stay
/// pure and trivially table-testable — which is where most of the test suite lives, because
/// it is where extraction bugs actually are.
public struct NormalizationRules: Sendable, Hashable {
    /// How to read an ambiguous date. Declared per template, never guessed from the locale,
    /// so one dataset stays internally consistent.
    public let dateConvention: DateConvention

    /// Tried before the standard format list when present.
    public let preferredDateFormat: String?

    public let currencyCode: String?

    /// For `.choice`. Values are fuzzy-matched to the nearest of these.
    public let choices: [String]

    /// Failure lowers confidence; it never rejects the value.
    public let validationPattern: String?

    /// Display-only suffix such as "kg" or "hrs". Stripped before parsing.
    public let unitSuffix: String

    public init(
        dateConvention: DateConvention = .dayMonthYear,
        preferredDateFormat: String? = nil,
        currencyCode: String? = nil,
        choices: [String] = [],
        validationPattern: String? = nil,
        unitSuffix: String = ""
    ) {
        self.dateConvention = dateConvention
        self.preferredDateFormat = preferredDateFormat
        self.currencyCode = currencyCode
        self.choices = choices
        self.validationPattern = validationPattern
        self.unitSuffix = unitSuffix
    }

    /// The rules for one field of a template.
    public static func forField(
        _ field: FieldSnapshot,
        in template: TemplateSnapshot
    ) -> NormalizationRules {
        NormalizationRules(
            dateConvention: template.dateConvention,
            preferredDateFormat: template.preferredDateFormat,
            currencyCode: field.currencyCode,
            choices: field.choices,
            validationPattern: field.validationPattern,
            unitSuffix: ""
        )
    }
}
