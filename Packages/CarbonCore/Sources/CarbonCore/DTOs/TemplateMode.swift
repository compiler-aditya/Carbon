/// How many records one page of this form produces.
///
/// Raw values are persisted. Never rename a case; only add.
public enum TemplateMode: String, Codable, Sendable, CaseIterable {
    /// One page produces one record. An intake form, a job card.
    case record

    /// One page produces one record per detected table row. A register, a log sheet.
    case table
}
