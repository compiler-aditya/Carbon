import CarbonCore
// Still needed for `FakePageStore`, the last-resort page store below — which is also how a
// fake meter came to be wired into the shipping app. Worth removing that dependency, but not
// in the same change as fixing the meter.
import CarbonTestFixtures
import RevenueCat
import SwiftData

extension Services {
    /// The service set the running app uses.
    ///
    /// Takes the container because the meter is persisted in it. It used to take nothing and
    /// wire the in-memory fake, which meant the free-tier record limit reset on every launch
    /// and Settings reported zero records in a month that had plenty.
    ///
    /// Entitlements are live whenever RevenueCat is configured, and a fixed `.unknown`
    /// otherwise. `Purchases.shared` traps if the SDK was never configured, so that branch is
    /// load-bearing rather than defensive.
    @MainActor
    static func live(container: ModelContainer) -> Services {
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
            extractor: LadderExtractor(resolver: FoundationModelResolver()),
            normalizer: StandardNormalizer(),
            exporter: CSVExporter(),
            entitlements: entitlements,
            meter: LiveUsageMetering(modelContainer: container)
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
