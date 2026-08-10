import CarbonCore
import Foundation

/// The real gating arithmetic over in-memory counters.
///
/// Unlike the other fakes this one does implement the rules, because the rules *are* the
/// thing being previewed: a meter bar at 18 of 20 and a meter bar at 20 of 20 are different
/// screens, and the boundary is exactly where the paywall has to behave well.
public actor FakeUsageMeter: UsageMetering {
    private var recordsCreated: Int
    private var templatesCreated: Int
    private let periodKey: String

    public init(recordsCreated: Int = 0, templatesCreated: Int = 0, periodKey: String? = nil) {
        self.recordsCreated = recordsCreated
        self.templatesCreated = templatesCreated
        self.periodKey = periodKey ?? UsagePeriodSnapshot.periodKey(for: .now)
    }

    /// One record short of the free limit — the state the demo is filmed in.
    public static var nearRecordLimit: FakeUsageMeter {
        FakeUsageMeter(recordsCreated: FreeTierLimit.recordsPerPeriod - 1, templatesCreated: 1)
    }

    public static var atRecordLimit: FakeUsageMeter {
        FakeUsageMeter(recordsCreated: FreeTierLimit.recordsPerPeriod, templatesCreated: 1)
    }

    public func currentPeriod() async -> UsagePeriodSnapshot {
        UsagePeriodSnapshot(
            periodKey: periodKey,
            recordsCreated: recordsCreated,
            templatesCreated: templatesCreated,
            firstSeenAt: .now
        )
    }

    public func canCreateTemplate(existingCount: Int, isPro: Bool) async -> MeterDecision {
        if isPro { return .allowed }
        return existingCount < FreeTierLimit.templates ? .allowed : .paywall(reason: .templateLimit)
    }

    public func canCreateRecords(count: Int, isPro: Bool) async -> MeterDecision {
        if isPro { return .allowed }
        let remaining = FreeTierLimit.recordsPerPeriod - recordsCreated
        if remaining <= 0 { return .paywall(reason: .recordLimit) }
        if count <= remaining { return .allowed }
        // Some of the page fits. Save those rows rather than refusing the whole scan.
        return .partial(allowed: remaining)
    }

    public func recordCreated(count: Int) async {
        recordsCreated += count
    }

    public func templateCreated() async {
        templatesCreated += 1
    }
}
