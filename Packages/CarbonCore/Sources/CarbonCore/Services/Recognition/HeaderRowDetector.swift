import Foundation

/// Guesses which row of a table is its header.
///
/// Vision reports a grid; it does not say which row names the columns. The rule here is
/// deliberately narrow — only the first row is ever a candidate, and only when it is entirely
/// non-numeric while something below it is numeric. A ruled register whose header is printed
/// above the grid, or a page cropped below its heading, correctly gets no header at all.
///
/// Returning `nil` is a good outcome, not a failure: with no header row every row carries
/// data, which is the right reading of a form whose columns were mapped by hand.
enum HeaderRowDetector {
    static func index(in rows: [[RecognizedCell]]) -> Int? {
        guard rows.count >= 2, let first = rows.first, !first.isEmpty else { return nil }

        // Every cell in a header says something, and none of it is a number.
        let firstRowIsLabels = first.allSatisfy { cell in
            !cell.text.trimmingCharacters(in: .whitespaces).isEmpty && !looksNumeric(cell.text)
        }
        guard firstRowIsLabels else { return nil }

        // …and at least one row beneath it holds a number. Without that, this is probably a
        // text-only table whose first row is data like any other.
        let bodyHasNumbers = rows.dropFirst().contains { row in
            row.contains { looksNumeric($0.text) }
        }
        return bodyHasNumbers ? 0 : nil
    }

    /// Digits, separators, currency marks and signs only — and at least one digit.
    ///
    /// "12", "1,200.50" and "₹560" are numeric. "Qty", "Item 1" and "" are not: a header cell
    /// that happens to contain a digit is still a header.
    static func looksNumeric(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.contains(where: \.isNumber) else { return false }

        let allowed: Set<Character> = [",", ".", "-", "+", "(", ")", "%", "/", " "]
        let currency: Set<Character> = ["₹", "$", "€", "£", "¥", "₽", "₩", "¢"]
        return trimmed.allSatisfy { character in
            character.isNumber || allowed.contains(character) || currency.contains(character)
        }
    }
}
