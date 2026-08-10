import CarbonCore

extension Services {
    /// The service set every `#Preview` uses. Deterministic, offline, and instant.
    ///
    /// Consequence: every screen has a working preview with realistic data from the first
    /// day, with no camera, no model and no purchase. That is what lets the interface be
    /// built while the pipeline is still being written.
    ///
    /// Entitlements default to the immutable `StaticEntitlementService` so this stays
    /// constructible off the main actor, which is what `@Entry` needs for the environment's
    /// default value. Pass a `FakeEntitlementService` when a preview or a test needs the
    /// status to *change* — a purchase landing, an expiry mid-session.
    public static func preview(
        entitlements: any EntitlementProviding = StaticEntitlementService(status: .free),
        meter: FakeUsageMeter = FakeUsageMeter(),
        recognizer: FakeRecognizer = FakeRecognizer()
    ) -> Services {
        Services(
            pageStore: FakePageStore(),
            recognizer: recognizer,
            extractor: FakeExtractor(),
            normalizer: FakeNormalizer(),
            exporter: FakeExporter(),
            entitlements: entitlements,
            meter: meter
        )
    }

    /// A Pro user with room to spare. For previewing screens with no lock symbols on them.
    public static func previewPro() -> Services {
        preview(
            entitlements: StaticEntitlementService(status: .pro),
            meter: FakeUsageMeter(recordsCreated: 137, templatesCreated: 4)
        )
    }

    /// A free user who has just hit the record limit — the state the paywall has to handle
    /// well, and the state the demo is filmed in.
    public static func previewAtLimit() -> Services {
        preview(entitlements: StaticEntitlementService(status: .free), meter: .atRecordLimit)
    }

    /// What a fresh clone with no RevenueCat key actually runs as. Everything except
    /// purchasing must work here, so it deserves its own preview.
    public static func previewUnconfigured() -> Services {
        preview(entitlements: StaticEntitlementService(status: .unknown))
    }
}
