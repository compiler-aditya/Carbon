/// The free-tier meter: one template, twenty records per calendar month, no export.
///
/// Gating is on volume and egress, never on quality — extraction is identical on both tiers.
/// Nothing here throws, because a limit is not an error.
///
/// The meter is stored locally and a reinstall resets it. That is an accepted v1 trade-off:
/// entitlement state is authoritative via RevenueCat and the free limit is a courtesy, not
/// DRM. The README says so plainly rather than pretending otherwise.
public protocol UsageMetering: Sendable {
    /// Returns the snapshot, never the `@Model` — `UsagePeriod` is not `Sendable`.
    func currentPeriod() async -> UsagePeriodSnapshot

    func canCreateTemplate(existingCount: Int, isPro: Bool) async -> MeterDecision

    /// `count` is how many records the pending action would create. A table-mode page that
    /// would cross the limit comes back `.partial`, so the rows that fit are still saved.
    func canCreateRecords(count: Int, isPro: Bool) async -> MeterDecision

    func recordCreated(count: Int) async

    func templateCreated() async
}

/// The free-tier limits, in one place so the meter, the paywall copy and the tests cannot
/// drift apart.
public enum FreeTierLimit {
    public static let templates = 1
    public static let recordsPerPeriod = 20
}
