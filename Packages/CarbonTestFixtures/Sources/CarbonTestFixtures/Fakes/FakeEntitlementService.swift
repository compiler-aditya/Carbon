import CarbonCore
import Observation

/// Entitlement state with no RevenueCat behind it.
///
/// Every gated screen gets a preview in each tier by constructing this with a different
/// status — which is the only way the paywall, the lock symbols and the meter get looked at
/// as often as they need to be.
@MainActor
@Observable
public final class FakeEntitlementService: EntitlementProviding {
    public private(set) var status: EntitlementStatus
    public var isPro: Bool { status.isPro }

    /// Set to make `restore` throw, for the "restore found nothing" path.
    public var restoreError: (any Error)?

    /// How many times `refresh` has been called, so a test can assert the app does not block
    /// on entitlement resolution at launch.
    public private(set) var refreshCount = 0

    public init(status: EntitlementStatus = .free, restoreError: (any Error)? = nil) {
        self.status = status
        self.restoreError = restoreError
    }

    public static var pro: FakeEntitlementService { FakeEntitlementService(status: .pro) }
    public static var free: FakeEntitlementService { FakeEntitlementService(status: .free) }

    /// What a judge running with the placeholder key actually gets. Everything must work.
    public static var unknown: FakeEntitlementService { FakeEntitlementService(status: .unknown) }

    public func refresh() async {
        refreshCount += 1
    }

    public func restore() async throws {
        if let restoreError { throw restoreError }
        status = .pro
    }

    /// Simulates the entitlement changing underneath the app — a purchase in another session,
    /// or an expiry mid-session arriving on the customer info stream.
    public func simulateStatusChange(to newStatus: EntitlementStatus) {
        status = newStatus
    }
}
