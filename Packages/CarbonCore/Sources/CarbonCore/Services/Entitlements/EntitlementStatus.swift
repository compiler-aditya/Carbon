/// What Carbon currently believes about the user's entitlement.
///
/// `unknown` is a real state, not a placeholder: at cold launch, before RevenueCat has
/// answered — or forever, if a judge runs this with the placeholder key — we know nothing.
/// Everywhere that gates behaviour must treat `unknown` as `free` and carry on. Nothing in
/// capture, extraction, review or the dataset may wait on this resolving.
public enum EntitlementStatus: String, Sendable, Hashable, CaseIterable {
    case unknown
    case free
    case pro

    /// Whether Pro features are unlocked. Only a confirmed `pro` opens the gate; `unknown`
    /// fails closed to free, which is the honest default and never blocks the app.
    public var isPro: Bool { self == .pro }
}
