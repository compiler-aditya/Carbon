/// Dependency injection, such as it is: a plain struct carried in the SwiftUI environment.
///
/// No container, no registration, no resolution at runtime. Seven properties and two factory
/// methods is the whole mechanism, and a reader can see every dependency the app has in one
/// screenful.
///
/// `live()` is built by the app target, which owns the concrete implementations.
/// `preview()` is built by `CarbonTestFixtures` from fakes, and every `#Preview` uses it —
/// which is what lets the interface be built at full speed while the pipeline is still being
/// written, and why previews are a schedule decision rather than a nicety.
/// Deliberately **not** `@MainActor`, though the spec's sketch was. The container is a bag of
/// references with no state of its own, and isolation belongs to the services inside it — each
/// is already an actor or main-actor-bound in its own right. Marking the struct itself
/// `@MainActor` also makes `@Entry var services: Services = .preview()` impossible, because
/// the macro generates a nonisolated default.
public struct Services: Sendable {
    public var pageStore: any PageStoring
    public var recognizer: any Recognizing
    public var extractor: any StructuredExtracting
    public var normalizer: any Normalizing
    public var exporter: any Exporting
    public var entitlements: any EntitlementProviding
    public var meter: any UsageMetering

    public init(
        pageStore: any PageStoring,
        recognizer: any Recognizing,
        extractor: any StructuredExtracting,
        normalizer: any Normalizing,
        exporter: any Exporting,
        entitlements: any EntitlementProviding,
        meter: any UsageMetering
    ) {
        self.pageStore = pageStore
        self.recognizer = recognizer
        self.extractor = extractor
        self.normalizer = normalizer
        self.exporter = exporter
        self.entitlements = entitlements
        self.meter = meter
    }
}
