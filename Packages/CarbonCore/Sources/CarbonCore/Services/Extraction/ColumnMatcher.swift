import Foundation

/// Works out which column of a recognised table holds which declared field.
///
/// This is the mechanism the whole table mode rests on, and it is the thing that improves as
/// a template is used: every alias a user's correction adds gives it another way to recognise
/// the same column next time, with no model involved.
enum ColumnMatcher {
    /// Below this, a header is not considered a match at all. Set where "Amount" still
    /// matches a mangled "Arnount" but does not match "Date".
    static let minimumScore = 0.55

    struct Match: Sendable, Hashable {
        let fieldKey: String
        let columnIndex: Int

        /// How confident we are in the *mapping*, separate from how well the cell was read.
        /// A shaky header match should lower the confidence of every value in that column.
        let score: Double

        /// The header text as it was actually printed on this page. Kept so a match made by
        /// fuzzy comparison can be turned into an exact one next time.
        let headerText: String

        /// True when the header matched a declared alias character for character. Anything
        /// less was a guess that happened to be good enough, and is worth remembering.
        var wasExact: Bool { score >= 1.0 }
    }

    /// Assigns columns to fields, best matches first.
    ///
    /// Greedy rather than optimal, and one-to-one in both directions: a column serves at most
    /// one field and a field takes at most one column. On a register with "Rate" and "Amount"
    /// as separate columns, letting both bind to whichever scored higher would silently
    /// duplicate a column and lose the other, which is worse than leaving one unresolved.
    static func match(
        headerRow: [RecognizedCell],
        fields: [FieldSnapshot]
    ) -> [Match] {
        var candidates: [Match] = []

        for field in fields {
            let aliases = field.aliases.isEmpty ? [field.label] : field.aliases
            for (columnIndex, cell) in headerRow.enumerated() {
                let score = StringSimilarity.bestScore(for: cell.text, among: aliases)
                if score >= minimumScore {
                    candidates.append(
                        Match(
                            fieldKey: field.key,
                            columnIndex: columnIndex,
                            score: score,
                            headerText: cell.text
                        )
                    )
                }
            }
        }

        // Sort by score, then by key, so an equal-scoring tie resolves the same way every run.
        // A matcher that returns different answers for the same page is untestable.
        candidates.sort {
            $0.score == $1.score ? $0.fieldKey < $1.fieldKey : $0.score > $1.score
        }

        var takenFields: Set<String> = []
        var takenColumns: Set<Int> = []
        var accepted: [Match] = []

        for candidate in candidates
        where !takenFields.contains(candidate.fieldKey)
            && !takenColumns.contains(candidate.columnIndex) {
            accepted.append(candidate)
            takenFields.insert(candidate.fieldKey)
            takenColumns.insert(candidate.columnIndex)
        }

        return accepted.sorted { $0.columnIndex < $1.columnIndex }
    }

    /// Falls back to reading columns in the order the fields were declared.
    ///
    /// Used when the page has no header row at all. It is a real guess and is scored as one,
    /// so every value it produces lands in the review band rather than pretending to be
    /// certain — the user mapped these fields by hand and is the one who can confirm it.
    static func positionalMatches(columnCount: Int, fields: [FieldSnapshot]) -> [Match] {
        zip(fields, 0..<columnCount).map { field, index in
            // No header means nothing to learn from — an empty headerText keeps the write
            // path from recording a column position as if it were a name.
            Match(fieldKey: field.key, columnIndex: index, score: 0.5, headerText: "")
        }
    }
}
