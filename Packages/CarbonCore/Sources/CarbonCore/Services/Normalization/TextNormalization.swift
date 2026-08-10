import Foundation

/// Pure string cleanup. No state, no isolation, no dependencies.
public enum TextNormalization {
    /// Characters recognition invents from ruled lines, staple holes and paper creases.
    /// Stripped only when isolated — a `|` inside "A|B" might be real, one standing alone
    /// between spaces is a vertical rule the recogniser mistook for a glyph.
    private static let artefacts: Set<Character> = ["|", "~", "¦", "†"]

    /// Trims, collapses runs of whitespace, and drops isolated OCR artefacts.
    public static func clean(_ raw: String) -> String {
        raw
            .split(whereSeparator: \.isWhitespace)
            .filter { token in
                !(token.count == 1 && artefacts.contains(token[token.startIndex]))
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cleanup for a free-text field.
    public static func normalizeText(_ raw: String) -> NormalizedValue {
        let cleaned = clean(raw)
        return cleaned.isEmpty ? .empty : .exact(cleaned)
    }

    /// An identifier is trimmed and nothing else.
    ///
    /// No whitespace collapsing, no artefact stripping, no case changes. An invoice number
    /// that gets helpfully cleaned up is an invoice number that no longer matches the
    /// customer's own records, and the whole point of the field is that it matches.
    public static func normalizeIdentifier(_ raw: String) -> NormalizedValue {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .empty : .exact(trimmed)
    }

    /// Digits and a leading `+`. Formatting is presentation and is not stored.
    public static func normalizePhone(_ raw: String) -> NormalizedValue {
        let cleaned = clean(raw)
        let hasPlus = cleaned.hasPrefix("+")
        let digits = cleaned.filter(\.isNumber)
        guard !digits.isEmpty else { return .empty }

        let text = hasPlus ? "+\(digits)" : digits
        // Shorter than seven digits is not a phone number anywhere; keep it, flag it.
        return digits.count >= 7 ? .exact(text) : .uncertain(text, multiplier: 0.5)
    }
}
