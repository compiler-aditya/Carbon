/// The kind of value a field holds. Drives normalization, the review keyboard, and CSV typing.
///
/// Raw values are persisted. Never rename a case; only add.
public enum FieldType: String, Codable, Sendable, CaseIterable {
    case text
    case integer
    case decimal
    case currency
    case date
    case time
    case boolean
    case choice
    case phone

    /// Invoice number, roll number. Text, but never auto-corrected or spell-normalized —
    /// an identifier that gets "helpfully" cleaned up is an identifier that no longer matches
    /// the customer's own records.
    case identifier
}
