/// Why the on-device model cannot be used right now.
///
/// The first three mirror `SystemLanguageModel.Availability.UnavailableReason` exactly — do
/// not add a fourth that the framework does not report. `unsupportedLanguage` is ours, and it
/// is deliberately separate: it comes from `supportsLocale(_:)` and can be true while
/// availability is perfectly fine. The two states need different sentences, because "the
/// feature is switched off" and "your language isn't covered yet" are different problems.
public enum ModelUnavailableReason: String, Sendable, Hashable, CaseIterable {
    /// The hardware cannot run the model.
    case deviceNotEligible

    /// The user has not turned Apple Intelligence on.
    case appleIntelligenceNotEnabled

    /// Still downloading. The one case worth re-checking on a later capture rather than
    /// caching for the whole session.
    case modelNotReady

    /// The device language is not in the model's supported set.
    case unsupportedLanguage

    /// Whether a later capture might find the model available. Only `modelNotReady` changes
    /// on its own; the rest need the user to do something, or a different device.
    public var isTransient: Bool { self == .modelNotReady }
}
