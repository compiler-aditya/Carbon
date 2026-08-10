import Foundation
import SwiftData

/// One declared field of a template.
@Model
public final class FieldDefinition {
    public var id: UUID = UUID()

    /// Stable machine key, snake_case. The CSV column key and the App Intent parameter name.
    ///
    /// Generated from `label` at creation and then **frozen**. Exports land in someone's
    /// spreadsheet, and a renamed column silently breaks their formulas. Label is
    /// presentation; key is contract.
    public var key: String = ""

    public var label: String = ""
    public var order: Int = 0

    public var typeRaw: String = FieldType.text.rawValue
    public var isRequired: Bool = false

    /// Header synonyms matched against in table mode. Seeded from `label` and extended by
    /// user corrections.
    public var columnAliases: [String] = []

    /// For `.choice` — the allowed values. Constrains the runtime generation schema.
    public var choices: [String] = []

    public var defaultValue: String = ""

    /// "kg", "hrs" — display only, stripped before parsing.
    public var unitSuffix: String = ""

    /// ISO 4217, for `.currency`.
    public var currencyCode: String = ""

    /// Optional pattern the value should satisfy. Failure lowers confidence; it never rejects
    /// the value. Silently dropping what someone wrote on the page is never correct.
    public var validationPattern: String = ""

    /// Where this field's value was found last time, normalised 0–1, as JSON. A positional
    /// prior for record-mode matching. Nil until the first success.
    public var lastKnownFrameJSON: String?

    @Relationship public var template: FormTemplate?

    public init() {}

    public var type: FieldType {
        get { FieldType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    /// Everything Tier 1 will match a header cell against: the label, the declared aliases,
    /// and anything the template has learned. Deduped and lowercased once, here.
    public func matchingAliases(learned: [String]) -> [String] {
        var seen = Set<String>()
        return ([label] + columnAliases + learned)
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
