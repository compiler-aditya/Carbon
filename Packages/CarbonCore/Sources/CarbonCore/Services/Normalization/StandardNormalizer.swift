import Foundation

/// The production normalizer. Dispatches to a pure function per field type.
///
/// Runs on every value regardless of which tier produced it, so Tier 1 and Tier 2 output
/// cannot disagree about what "1,200" means.
public struct StandardNormalizer: Normalizing {
    public init() {}

    public func normalize(
        _ raw: String,
        as type: FieldType,
        using rules: NormalizationRules
    ) -> NormalizedValue {
        switch type {
        case .text:
            TextNormalization.normalizeText(raw)
        case .identifier:
            TextNormalization.normalizeIdentifier(raw)
        case .phone:
            TextNormalization.normalizePhone(raw)
        case .integer:
            NumberNormalization.normalizeInteger(raw, unitSuffix: rules.unitSuffix)
        case .decimal:
            NumberNormalization.normalizeDecimal(raw, unitSuffix: rules.unitSuffix)
        case .currency:
            NumberNormalization.normalizeCurrency(raw, unitSuffix: rules.unitSuffix)
        case .date, .time, .boolean, .choice:
            // Type-aware handling for these lands next. Cleaning the text is correct in the
            // meantime — it is what the value would get as free text — and it never discards
            // what was written on the page.
            TextNormalization.normalizeText(raw)
        }
    }
}
