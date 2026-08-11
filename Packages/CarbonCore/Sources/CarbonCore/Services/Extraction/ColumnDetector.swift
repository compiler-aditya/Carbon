import Foundation

/// A column found on a scanned form, ready to become a field.
public struct DetectedColumn: Sendable, Hashable {
    /// The header as printed on the page, tidied but not reworded.
    public let label: String

    /// Guessed from what is underneath the header, not from the header alone.
    public let type: FieldType

    /// The raw header spelling, kept so the template can match this page exactly next time.
    public let alias: String

    /// A few values from the column, for a preview that lets someone check the guess before
    /// accepting it.
    public let samples: [String]

    public init(label: String, type: FieldType, alias: String, samples: [String]) {
        self.label = label
        self.type = type
        self.alias = alias
        self.samples = samples
    }
}

/// Turns a scanned table into draft fields.
///
/// This is the inverse of what `DeterministicExtractor` does. Extraction matches a page against
/// fields the user already declared; this reads the page when there are no fields yet, so the
/// user declares them by confirming rather than by typing. One tap instead of five labels and
/// five type pickers.
///
/// It guesses from the **body** of each column, not from its header. "Amount" is a plausible
/// name for a text column and "Reference" is a plausible name for a number, so the header only
/// breaks ties — what is actually written under it decides.
public enum ColumnDetector {
    /// Share of a column's values that must agree before a type is claimed.
    ///
    /// Not unanimity: one misread cell in a column of ten should not demote a currency column
    /// to text, and a form is scanned precisely because reading it is imperfect. Not a bare
    /// majority either — that guesses confidently off three cells and two coincidences.
    static let agreement = 0.6

    public static func columns(in page: RecognizedPage) -> [DetectedColumn] {
        guard let table = page.primaryTable, let header = table.headerRow else { return [] }

        return header.compactMap { cell -> DetectedColumn? in
            // A header spanning two columns describes neither of them. Better to leave it out
            // and let the user add that field than to invent a name for a merged heading.
            guard !cell.isSpanning else { return nil }

            let label = tidy(cell.text)
            guard !label.isEmpty else { return nil }

            let index = cell.columnRange.lowerBound
            let samples = values(inColumn: index, of: table)

            return DetectedColumn(
                label: label,
                type: type(forHeader: label, samples: samples),
                alias: label.lowercased(),
                samples: Array(samples.prefix(3))
            )
        }
    }

    /// Every non-empty value under one header, in page order.
    static func values(inColumn index: Int, of table: RecognizedTable) -> [String] {
        table.dataRows.compactMap { row in
            let text = row.first { !$0.isSpanning && $0.columnRange.lowerBound == index }?.text
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// Collapses the whitespace recognition leaves behind, without rewording anything.
    ///
    /// The label a user sees has to be the label on their form. "QTY." stays "QTY." — deciding
    /// it should read "Quantity" is the app overruling the paper, which is the one thing this
    /// product must never do.
    static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ":|"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func type(forHeader header: String, samples: [String]) -> FieldType {
        let hint = header.lowercased()

        // Nothing to read: the header is all there is, so it has to carry the guess alone.
        guard !samples.isEmpty else { return headerOnlyType(hint) }

        func share(_ matches: (String) -> Bool) -> Double {
            Double(samples.count(where: matches)) / Double(samples.count)
        }

        if share(looksLikeDate) >= agreement { return .date }
        if suggestsPhone(hint), share(looksLikePhone) >= agreement { return .phone }

        // A currency column rarely prints its symbol on every row — often on none of them —
        // so a numeric column under a money heading is money.
        let numeric = share { looksLikeInteger($0) || looksLikeDecimal($0) }
        if share(hasCurrencySymbol) >= agreement { return .currency }
        if suggestsCurrency(hint), numeric >= agreement { return .currency }

        if share(looksLikeInteger) >= agreement { return .integer }
        if numeric >= agreement { return .decimal }
        return .text
    }

    private static func headerOnlyType(_ hint: String) -> FieldType {
        if suggestsCurrency(hint) { return .currency }
        if suggestsPhone(hint) { return .phone }
        if suggestsDate(hint) { return .date }
        if suggestsCount(hint) { return .integer }
        return .text
    }

    // MARK: Header hints
    //
    // Whole-word matching, because "no" is a count and "notes" is not, and a substring rule
    // would type a Notes column as a number on every register that has one.

    /// Lowercases here rather than trusting the caller to have done it. These are the kind of
    /// predicate that fails silently and always returns false when handed "Qty" instead of
    /// "qty", which is a bug that would only ever show up as a column typed as text.
    private static func words(_ hint: String) -> Set<String> {
        Set(hint.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
    }

    static func suggestsCurrency(_ hint: String) -> Bool {
        !words(hint).isDisjoint(with: [
            "amount", "amt", "rate", "price", "cost", "total", "value", "fee", "charge",
            "paid", "due", "balance",
        ])
    }

    static func suggestsCount(_ hint: String) -> Bool {
        !words(hint).isDisjoint(with: ["qty", "quantity", "count", "no", "num", "pcs", "units"])
    }

    static func suggestsPhone(_ hint: String) -> Bool {
        !words(hint).isDisjoint(with: ["phone", "mobile", "contact", "tel", "cell"])
    }

    static func suggestsDate(_ hint: String) -> Bool {
        !words(hint).isDisjoint(with: ["date", "day", "dated", "on"])
    }

    // MARK: Value shapes

    static func looksLikeDate(_ value: String) -> Bool {
        value.wholeMatch(of: /\s*\d{1,4}[-\/.]\d{1,2}[-\/.]\d{2,4}\s*/) != nil
    }

    static func looksLikePhone(_ value: String) -> Bool {
        let digits = value.filter(\.isNumber)
        return digits.count >= 7 && digits.count <= 15
            && value.allSatisfy { $0.isNumber || $0 == "+" || $0 == "-" || $0 == " " || $0 == "(" || $0 == ")" }
    }

    static func hasCurrencySymbol(_ value: String) -> Bool {
        value.contains(where: { "₹$€£¥".contains($0) }) || value.lowercased().contains("rs")
    }

    static func looksLikeInteger(_ value: String) -> Bool {
        let stripped = value.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return !stripped.isEmpty && stripped.allSatisfy(\.isNumber)
    }

    static func looksLikeDecimal(_ value: String) -> Bool {
        let stripped = value.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return stripped.wholeMatch(of: /\d+\.\d+/) != nil
    }
}
