import Foundation

/// An immutable projection of one `UsagePeriod`.
///
/// `UsagePeriod` is a `@Model` and therefore not `Sendable`, so the metering service returns
/// this instead. Small enough that passing the model directly would look harmless, which is
/// exactly why it is spelled out.
public struct UsagePeriodSnapshot: Sendable, Hashable {
    /// The calendar month this covers, as "2026-09", in the user's own calendar.
    public let periodKey: String

    public let recordsCreated: Int
    public let templatesCreated: Int
    public let firstSeenAt: Date

    public init(periodKey: String, recordsCreated: Int, templatesCreated: Int, firstSeenAt: Date) {
        self.periodKey = periodKey
        self.recordsCreated = recordsCreated
        self.templatesCreated = templatesCreated
        self.firstSeenAt = firstSeenAt
    }

    /// The key for a given date. One place, so the meter and any display of it agree about
    /// where a month boundary falls.
    public static func periodKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else { return "" }
        return String(format: "%04d-%02d", year, month)
    }
}
