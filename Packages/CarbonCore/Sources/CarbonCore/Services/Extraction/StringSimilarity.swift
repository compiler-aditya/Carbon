import Foundation

/// How alike two short strings are, 0 to 1.
///
/// Used to match a printed column header against a field's declared aliases. Recognition
/// makes small errors on printed headers — "Amount" arrives as "Arnount", "Qty" as "Otv" —
/// and an exact-match rule would send perfectly readable columns to the model for no reason.
enum StringSimilarity {
    /// Lowercased, with punctuation and whitespace removed.
    ///
    /// "Rate / unit", "rate/unit" and "RATE-UNIT" are the same header written three ways, and
    /// no useful distinction is lost by flattening them.
    static func canonical(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// 1.0 for identical strings, 0.0 for nothing in common.
    static func score(_ lhs: String, _ rhs: String) -> Double {
        let left = Array(canonical(lhs))
        let right = Array(canonical(rhs))

        if left.isEmpty || right.isEmpty { return left.isEmpty && right.isEmpty ? 1 : 0 }
        if left == right { return 1 }

        let longest = max(left.count, right.count)
        return 1 - Double(editDistance(left, right)) / Double(longest)
    }

    /// The best score across a set of candidates — a field's label plus every alias it has
    /// collected, including ones learned from user corrections.
    static func bestScore(for text: String, among candidates: [String]) -> Double {
        candidates.reduce(0) { max($0, score(text, $1)) }
    }

    /// Levenshtein distance, two rows rather than a full matrix. Headers are a few characters
    /// long, so this is not worth optimising further.
    static func editDistance(_ left: [Character], _ right: [Character]) -> Int {
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = [Int](repeating: 0, count: right.count + 1)

        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let substitution = previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }
}
