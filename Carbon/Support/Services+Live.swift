import CarbonCore
import CarbonTestFixtures
import RevenueCat

extension Services {
    /// The service set the running app uses.
    ///
    /// Capture, recognition, extraction, normalization and storage are all live. Two remain
    /// fakes and are called out rather than hidden:
    ///
    /// - `exporter` — CSV with full RFC-4180 handling is not written yet.
    /// - `meter` — counts are in memory, so they reset on launch. The gating arithmetic is
    ///   real; only its persistence is missing.
    ///
    /// Entitlements are live whenever RevenueCat is configured, and a fixed `.unknown`
    /// otherwise. `Purchases.shared` traps if the SDK was never configured, so that branch is
    /// load-bearing rather than defensive.
    @MainActor
    static func live() -> Services {
        let entitlements: any EntitlementProviding =
            Purchases.isConfigured
            ? LiveEntitlementService()
            : StaticEntitlementService(status: .unknown)

        if let live = entitlements as? LiveEntitlementService {
            live.start()
        }

        return Services(
            pageStore: makePageStore(),
            recognizer: LiveRecognizer(),
            extractor: DeterministicExtractor(),
            normalizer: StandardNormalizer(),
            exporter: FakeExporter(),
            entitlements: entitlements,
            meter: FakeUsageMeter()
        )
    }

    /// Falls back to an in-memory store if Application Support cannot be reached.
    ///
    /// That should never happen on a real device, and if it somehow does, scans living only
    /// for the session is a far better outcome than refusing to launch. The rest of the app
    /// is unaffected either way.
    @MainActor
    private static func makePageStore() -> any PageStoring {
        (try? LivePageStore()) ?? FakePageStore()
    }
}
