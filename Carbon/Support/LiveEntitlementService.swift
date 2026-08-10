import CarbonCore
import Observation
import RevenueCat

/// The only type in the codebase that touches `Purchases.shared`.
///
/// Everything else talks to `EntitlementProviding`. That boundary is not ceremony — it is
/// what lets the gating rules be unit-tested without a store, and it means swapping or
/// removing RevenueCat would touch exactly one file.
@MainActor
@Observable
final class LiveEntitlementService: EntitlementProviding {
    /// The single entitlement. One Pro level; multiple tiers would be over-engineering.
    private static let proEntitlementID = "pro"

    private(set) var status: EntitlementStatus = .unknown
    var isPro: Bool { status.isPro }

    private var streamTask: Task<Void, Never>?

    /// Begins resolving entitlement state. Never awaited before first paint — the UI renders
    /// from `.unknown`, which is treated as free everywhere, and corrects itself when the
    /// answer arrives.
    func start() {
        Task { await refresh() }

        streamTask = Task { [weak self] in
            // The stream is what makes this an integration rather than a wire-up: a purchase
            // made in another session, a restore, or an expiry all propagate here with no
            // manual refresh anywhere in the app.
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    /// Ends the stream. Not called in `deinit`, which is nonisolated and cannot touch
    /// main-actor state; this service is created once for the app's lifetime, so there is no
    /// point at which that would fire anyway. The method exists so a test can tear one down.
    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    func refresh() async {
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // Fail open. A network problem must never leave someone unable to use the app,
            // and treating an unresolved state as free is the honest default.
            status = .free
        }
    }

    func restore() async throws {
        apply(try await Purchases.shared.restorePurchases())
    }

    private func apply(_ info: CustomerInfo) {
        status = info.entitlements[Self.proEntitlementID]?.isActive == true ? .pro : .free
    }
}
