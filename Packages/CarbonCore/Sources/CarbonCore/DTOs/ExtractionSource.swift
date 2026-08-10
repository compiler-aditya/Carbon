/// Where a value came from. Carried on every `FieldValue` so the review UI can be honest
/// about what Carbon knows versus what it inferred.
///
/// Raw values are persisted. Never rename a case; only add.
public enum ExtractionSource: String, Codable, Sendable, CaseIterable {
    /// Tier 1 — layout and header matching, no model involved.
    case deterministic

    /// Tier 2 — the on-device model mapped page text onto the template.
    case model

    /// Typed or corrected by a human. Always confidence 1.0.
    case userEntered

    /// Tier 3 — nothing was found. A normal outcome, not an error.
    case unresolved

    /// The template's declared default was applied.
    case defaultValue
}
