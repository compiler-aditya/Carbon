/// How to read an ambiguous date on this form.
///
/// Declared per template rather than guessed from the device locale, because a dataset
/// that resolves `03/04/2026` one way in March and another way in April is worse than
/// one that is consistently wrong.
///
/// Raw values are persisted. Never rename a case; only add.
public enum DateConvention: String, Codable, Sendable, CaseIterable {
    case dayMonthYear
    case monthDayYear
    case yearMonthDay
}
