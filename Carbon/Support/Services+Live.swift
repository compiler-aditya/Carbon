import CarbonCore
import CarbonTestFixtures
import RevenueCat

extension Services {
    /// The service set the running app uses.
    ///
    /// Entitlements are live whenever RevenueCat is configured, and a fixed `.unknown`
    /// otherwise. `Purchases.shared` traps if the SDK was never configured, so the branch is
    /// load-bearing rather than defensive — and with a placeholder key there is genuinely
    /// nothing to observe, so a static answer is more honest than a stalled SDK.
    ///
    /// The remaining services are still fakes. The pipeline is being built behind these
    /// protocols and the screens are being built in front of them; this is what lets those
    /// happen at the same time. Each one is replaced with its live implementation as it
    /// lands, and this comment goes with the last of them.
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
            pageStore: FakePageStore(),
            recognizer: FakeRecognizer(),
            extractor: FakeExtractor(),
            normalizer: StandardNormalizer(),
            exporter: FakeExporter(),
            entitlements: entitlements,
            meter: FakeUsageMeter()
        )
    }
}
