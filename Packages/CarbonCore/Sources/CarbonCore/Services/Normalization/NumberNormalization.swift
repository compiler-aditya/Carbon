import Foundation

/// Parsing numbers off a form, where the writer's separator convention is unknown and the
/// recogniser may have mangled it.
public enum NumberNormalization {
    /// Symbols and codes that mean "this is money" and carry no numeric information.
    private static let currencyMarkers: Set<Character> = [
        "₹", "$", "€", "£", "¥", "₽", "₩", "﷼", "¢",
    ]

    /// Strips currency markers, letters, spaces and the declared unit suffix, leaving only
    /// digits, separators and a sign.
    private static func stripToNumeric(_ raw: String, unitSuffix: String) -> String {
        var working = TextNormalization.clean(raw)

        if !unitSuffix.isEmpty {
            working = working.replacingOccurrences(
                of: unitSuffix, with: "", options: [.caseInsensitive]
            )
        }

        // A leading minus, or a value wrapped in brackets, both mean negative. Registers use
        // both, and the bracket form is common in anything derived from an accounts book.
        let isBracketed = working.hasPrefix("(") && working.hasSuffix(")")
        let isNegative = working.hasPrefix("-") || isBracketed

        let digitsAndSeparators = working.filter { $0.isNumber || $0 == "," || $0 == "." }
        guard !digitsAndSeparators.isEmpty else { return "" }
        return isNegative ? "-\(digitsAndSeparators)" : digitsAndSeparators
    }

    /// Resolves which separator is the decimal point, then produces a canonical value.
    ///
    /// The genuinely ambiguous case — a single separator with exactly three digits after it,
    /// like "1,200" — is read as a thousands separator, which is right far more often on a
    /// sales register, but the confidence is dropped so it surfaces for review rather than
    /// being silently decided. Guessing quietly is the failure mode this whole app exists to
    /// remove.
    public static func normalizeDecimal(_ raw: String, unitSuffix: String = "") -> NormalizedValue {
        let numeric = stripToNumeric(raw, unitSuffix: unitSuffix)
        guard !numeric.isEmpty else { return .empty }

        let isNegative = numeric.hasPrefix("-")
        let body = isNegative ? String(numeric.dropFirst()) : numeric

        let commaCount = body.count { $0 == "," }
        let dotCount = body.count { $0 == "." }

        var integerPart = body
        var fractionPart = ""
        var isAmbiguous = false

        if commaCount > 0 && dotCount > 0 {
            // Whichever comes last is the decimal point; the other groups thousands.
            let lastComma = body.lastIndex(of: ",")
            let lastDot = body.lastIndex(of: ".")
            let decimalIndex = max(lastComma!, lastDot!)
            integerPart = String(body[body.startIndex..<decimalIndex])
            fractionPart = String(body[body.index(after: decimalIndex)...])
        } else if commaCount + dotCount == 1 {
            let separator: Character = commaCount == 1 ? "," : "."
            let index = body.lastIndex(of: separator)!
            let after = String(body[body.index(after: index)...])
            let before = String(body[body.startIndex..<index])

            if after.count == 3 && !before.isEmpty {
                // "1,200" or "1.200" — thousands or decimal, no way to know from the string.
                isAmbiguous = true
                integerPart = body
            } else {
                integerPart = before
                fractionPart = after
            }
        }

        let digits = integerPart.filter(\.isNumber)
        let fractionDigits = fractionPart.filter(\.isNumber)
        guard !digits.isEmpty || !fractionDigits.isEmpty else { return .empty }

        let whole = digits.isEmpty ? "0" : String(Int(digits) ?? 0)
        let text =
            fractionDigits.isEmpty
            ? "\(isNegative ? "-" : "")\(whole)"
            : "\(isNegative ? "-" : "")\(whole).\(fractionDigits)"

        return isAmbiguous ? .uncertain(text, multiplier: 0.7) : .exact(text)
    }

    /// A whole number. A value with a fractional part is kept but flagged, because the field
    /// was declared as a count and dropping the fraction silently would change the data.
    public static func normalizeInteger(_ raw: String, unitSuffix: String = "") -> NormalizedValue {
        let decimal = normalizeDecimal(raw, unitSuffix: unitSuffix)
        guard !decimal.text.isEmpty else { return .empty }

        guard let dotIndex = decimal.text.firstIndex(of: ".") else { return decimal }

        let whole = String(decimal.text[decimal.text.startIndex..<dotIndex])
        return .uncertain(whole, multiplier: 0.6)
    }

    /// Money. Same parsing as a decimal; the currency code lives on the field, not in the
    /// stored value, so the CSV holds a number a spreadsheet can total.
    public static func normalizeCurrency(_ raw: String, unitSuffix: String = "") -> NormalizedValue {
        let stripped = String(raw.filter { !currencyMarkers.contains($0) })
        return normalizeDecimal(stripped, unitSuffix: unitSuffix)
    }
}
