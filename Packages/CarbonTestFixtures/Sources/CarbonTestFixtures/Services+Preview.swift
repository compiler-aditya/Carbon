import CarbonCore

extension Services {
    /// The service set every `#Preview` uses. Deterministic, offline, and instant.
    ///
    /// Consequence: every screen has a working preview with realistic data from the first
    /// day, with no camera, no model and no purchase. That is what lets the interface be
    /// built while the pipeline is still being written.
    public static func preview(
        entitlements: FakeEntitlementService = .free,
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
        preview(entitlements: .pro, meter: FakeUsageMeter(recordsCreated: 137, templatesCreated: 4))
    }

    /// A free user who has just hit the record limit — the state the paywall has to handle
    /// well, and the state the demo is filmed in.
    public static func previewAtLimit() -> Services {
        preview(entitlements: .free, meter: .atRecordLimit)
    }
}
