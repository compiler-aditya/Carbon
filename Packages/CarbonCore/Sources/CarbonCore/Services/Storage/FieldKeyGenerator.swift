import Foundation

/// Turns a user's field label into the stable machine key used as the CSV column and the App
/// Intent parameter name.
///
/// The key is generated once, at creation, and then **frozen**. Exports land in someone's
/// spreadsheet and a renamed column silently breaks their formulas, so the label stays
/// editable and the key never moves. Label is presentation; key is contract.
public enum FieldKeyGenerator {
    /// snake_case, ASCII letters and digits only.
    ///
    /// A label that reduces to nothing — "₹", "#" — falls back to "field" rather than an
    /// empty key, because an empty CSV header is worse than a dull one.
    public static func key(from label: String) -> String {
        let folded = label.folding(options: [.diacriticInsensitive], locale: .current)

        var result = ""
        var lastWasSeparator = true  // leading separators are dropped

        for character in folded.lowercased() {
            if character.isLetter || character.isNumber {
                // Non-ASCII letters carry no meaning in a machine key; a label in another
                // script still gets a usable key from its digits, or the fallback below.
                if character.isASCII {
                    result.append(character)
                    lastWasSeparator = false
                }
            } else if !lastWasSeparator {
                result.append("_")
                lastWasSeparator = true
            }
        }

        while result.hasSuffix("_") { result.removeLast() }
        return result.isEmpty ? "field" : result
    }

    /// A key that does not collide with ones already used on the same template.
    ///
    /// Two fields labelled "Date" become `date` and `date_2`. Suffixing rather than refusing
    /// keeps the editor out of the user's way — duplicate labels are their business.
    public static func uniqueKey(from label: String, existing: Set<String>) -> String {
        let base = key(from: label)
        guard existing.contains(base) else { return base }

        var suffix = 2
        while existing.contains("\(base)_\(suffix)") {
            suffix += 1
        }
        return "\(base)_\(suffix)"
    }
}
