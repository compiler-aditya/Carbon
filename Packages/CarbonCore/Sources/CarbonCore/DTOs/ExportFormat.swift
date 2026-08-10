/// Export formats. Only `csv` is implemented in v1; the others are reserved so that adding
/// them later does not change any persisted raw value.
///
/// Raw values are persisted. Never rename a case; only add.
public enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case csv

    /// v1.1 — reserved, deliberately unimplemented.
    case xlsx

    /// v1.1 — reserved, deliberately unimplemented.
    case json

    /// Whether v1 can actually produce this format. The export sheet shows the others
    /// greyed rather than hiding them, so the roadmap is visible instead of implied.
    public var isAvailable: Bool { self == .csv }
}
