import Foundation
import SwiftData

/// The free-tier meter the app actually runs on, persisted in the store.
///
/// One `UsagePeriod` row per calendar month, found by key. **Rollover is not a scheduled job
/// and not a stored expiry date**: the key is computed from today, so the first scan in a new
/// month simply finds no row and starts from zero. Nothing has to run at midnight on the 1st,
/// there is no timer to miss while the app is closed, and a device whose clock moves lands in
/// the right month either way.
///
/// Old periods are kept rather than deleted. One row a month is nothing, and it is the only
/// record of what the free tier actually absorbed before someone subscribed.
///
/// Still local, so a reinstall resets it — the accepted v1 trade-off written on `UsagePeriod`
/// and in the README. Entitlement is authoritative via RevenueCat; this is a courtesy limit,
/// not DRM.
@ModelActor
public actor LiveUsageMetering: UsageMetering {
    public func currentPeriod() async -> UsagePeriodSnapshot {
        let key = Self.currentKey()

        // A month with nothing in it yet reports zero rather than nothing. The meter bar on
        // Settings should read "0 of 20" on the first of the month, not disappear.
        return period(forKey: key)?.snapshot
            ?? UsagePeriodSnapshot(
                periodKey: key, recordsCreated: 0, templatesCreated: 0, firstSeenAt: .now
            )
    }

    public func canCreateTemplate(existingCount: Int, isPro: Bool) async -> MeterDecision {
        .forTemplate(existingCount: existingCount, isPro: isPro)
    }

    public func canCreateRecords(count: Int, isPro: Bool) async -> MeterDecision {
        .forRecords(
            count: count,
            alreadyUsed: period(forKey: Self.currentKey())?.recordsCreated ?? 0,
            isPro: isPro
        )
    }

    public func recordCreated(count: Int) async {
        guard count > 0 else { return }
        thisMonth().recordsCreated += count
        save()
    }

    public func templateCreated() async {
        thisMonth().templatesCreated += 1
        save()
    }

    private static func currentKey() -> String {
        UsagePeriodSnapshot.periodKey(for: .now)
    }

    private func period(forKey key: String) -> UsagePeriod? {
        var descriptor = FetchDescriptor<UsagePeriod>(
            predicate: #Predicate { $0.periodKey == key }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// This month's row, created on first use.
    private func thisMonth() -> UsagePeriod {
        let key = Self.currentKey()
        if let existing = period(forKey: key) { return existing }

        let period = UsagePeriod()
        period.periodKey = key
        period.firstSeenAt = .now
        modelContext.insert(period)
        return period
    }

    /// A meter that fails to save has miscounted in the user's favour, which is the right
    /// direction for a courtesy limit to fail in and not worth an error path of its own.
    private func save() {
        try? modelContext.save()
    }
}
