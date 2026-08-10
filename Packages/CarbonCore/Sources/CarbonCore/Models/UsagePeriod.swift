import Foundation
import SwiftData

/// One calendar month of free-tier usage.
///
/// Local, so a reinstall resets it. Accepted v1 trade-off: entitlement is authoritative via
/// RevenueCat and this is a courtesy limit, not DRM.
@Model
public final class UsagePeriod {
    /// "2026-09", in the user's own calendar.
    public var periodKey: String = ""
    public var recordsCreated: Int = 0
    public var templatesCreated: Int = 0
    public var firstSeenAt: Date = Date()

    public init() {}

    /// The `Sendable` projection. Services take this; the model never leaves the store.
    public var snapshot: UsagePeriodSnapshot {
        UsagePeriodSnapshot(
            periodKey: periodKey,
            recordsCreated: recordsCreated,
            templatesCreated: templatesCreated,
            firstSeenAt: firstSeenAt
        )
    }
}
