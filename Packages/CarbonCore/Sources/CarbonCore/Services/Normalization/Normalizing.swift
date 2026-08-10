/// Turns a raw recognised string into its canonical form for a declared type.
///
/// Runs on every value regardless of which tier produced it, so behaviour is identical
/// across the ladder. Implementations are pure functions over strings with no isolation and
/// no state — the easiest thing in this codebase to test, and where most of the test suite
/// belongs.
public protocol Normalizing: Sendable {
    func normalize(_ raw: String, as type: FieldType, using rules: NormalizationRules)
        -> NormalizedValue
}
