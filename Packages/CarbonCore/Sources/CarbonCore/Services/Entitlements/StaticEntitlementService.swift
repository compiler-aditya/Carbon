import Observation

/// An entitlement provider whose answer never changes.
///
/// Two real uses, not just a test seam:
///
/// 1. **The zero-config path.** With no RevenueCat key configured — which is exactly what a
///    fresh clone has — there is nothing to observe and nothing that can change. Handing the
///    app this, set to `.unknown`, is more honest than standing up an SDK with a placeholder
///    key and waiting for it to fail.
/// 2. **The default environment value**, because it is immutable and therefore constructible
///    without the main actor, which `@Entry` requires.
///
/// Conforms to `Observable` without the macro. `Observable` has no requirements, and there is
/// nothing here to observe: every property is a `let`. That immutability is also what lets it
/// be `Sendable` without `@unchecked`.
/// `nonisolated` is load-bearing and must stay: conforming to a `@MainActor` protocol
/// otherwise infers main-actor isolation onto the whole class, which would make it
/// unconstructible from the nonisolated context `@Entry` generates. Nonisolated members
/// satisfy main-actor requirements perfectly well — they are strictly more available.
public nonisolated final class StaticEntitlementService: EntitlementProviding, Observable, Sendable {
    public let status: EntitlementStatus

    public init(status: EntitlementStatus) {
        self.status = status
    }

    public var isPro: Bool { status.isPro }

    /// Nothing to refresh. Deliberately not a failure — the app carries on as free tier.
    public func refresh() async {}

    /// Nothing to restore. Not an error state: "no previous purchase found" is the honest
    /// outcome and the UI says so plainly.
    public func restore() async throws {}
}
