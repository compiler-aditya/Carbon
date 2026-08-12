import CoreGraphics
import Foundation

extension Services {
    /// A service set that does nothing, for the one place a `Services` value is needed before
    /// anyone has supplied one: the environment key's default.
    ///
    /// It exists so that default is not a set of **test fakes**. Fakes there look like a
    /// convenience and behave like a trap — a screen that never received the real services
    /// would carry on working, showing invented rows and a meter that counts nothing, and
    /// nothing would look wrong. That is precisely how `FakeUsageMeter` came to ship inside
    /// the running app for a week.
    ///
    /// This set fails visibly instead: recognition returns an empty page, so extraction
    /// produces nothing and the app says "nothing matched this template" — which is the app
    /// telling the truth about a service set that cannot read anything.
    ///
    /// Previews do not use this. They inject `.preview()` explicitly, which is where realistic
    /// fake data belongs.
    public static var unconfigured: Services {
        Services(
            pageStore: EphemeralPageStore(),
            recognizer: UnconfiguredRecognizer(),
            extractor: LadderExtractor(),
            normalizer: StandardNormalizer(),
            exporter: CSVExporter(),
            entitlements: StaticEntitlementService(status: .unknown),
            meter: UnmeteredUsage()
        )
    }
}

/// Reads nothing from anything.
struct UnconfiguredRecognizer: Recognizing {
    func recognize(_ image: CGImage, pageID: UUID) async throws -> RecognizedPage {
        RecognizedPage(pageID: pageID, blocks: [], tables: [], detectedData: [], fullText: "")
    }
}

/// Counts nothing and refuses nothing.
///
/// Permissive rather than restrictive on purpose: an inert default should not be able to lock
/// someone out of their own app by reporting a limit that was never reached.
struct UnmeteredUsage: UsageMetering {
    func currentPeriod() async -> UsagePeriodSnapshot {
        UsagePeriodSnapshot(
            periodKey: UsagePeriodSnapshot.periodKey(for: .now),
            recordsCreated: 0,
            templatesCreated: 0,
            firstSeenAt: .now
        )
    }

    func canCreateTemplate(existingCount: Int, isPro: Bool) async -> MeterDecision { .allowed }
    func canCreateRecords(count: Int, isPro: Bool) async -> MeterDecision { .allowed }
    func recordCreated(count: Int) async {}
    func templateCreated() async {}
}
