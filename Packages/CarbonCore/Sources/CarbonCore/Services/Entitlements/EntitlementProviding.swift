import Observation

/// The app's single view of whether Pro is unlocked.
///
/// `@MainActor` and `@Observable` because it drives the UI directly — a lock symbol on the
/// export button has to flip the moment a purchase lands, without anyone calling refresh.
///
/// This protocol is the boundary that keeps RevenueCat out of the rest of the codebase.
/// `Purchases.shared` is touched in exactly one file, the live implementation; everything
/// else talks to this. That is what makes the purchase-flow tests possible at all.
@MainActor
public protocol EntitlementProviding: AnyObject, Observable {
    var isPro: Bool { get }
    var status: EntitlementStatus { get }

    /// Re-reads entitlement state. Must fail open to `.free` — never leave the user blocked
    /// because a network call did not come back.
    func refresh() async

    func restore() async throws
}
