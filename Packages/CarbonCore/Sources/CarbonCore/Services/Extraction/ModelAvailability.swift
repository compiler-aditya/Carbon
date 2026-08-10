import Foundation
import FoundationModels

/// Whether the on-device model can be used, and if not, why.
///
/// Checked once and cached, because the answer does not change mid-session for any reason
/// except a download finishing — which is the one case worth re-asking about.
public actor ModelAvailability {
    public enum State: Sendable, Hashable {
        case available
        case unavailable(ModelUnavailableReason)

        public var isAvailable: Bool { self == .available }
    }

    private var cached: State?

    public init() {}

    public func state(locale: Locale = .current) -> State {
        if let cached, cached != .unavailable(.modelNotReady) {
            return cached
        }

        let resolved = Self.resolve(locale: locale)
        cached = resolved
        return resolved
    }

    /// Maps the framework's answer onto ours.
    ///
    /// Availability and language support are separate questions: the model can be perfectly
    /// available and still not cover the user's language, and the two need different
    /// sentences in Settings. Checking availability first matters — `supportsLocale` on an
    /// ineligible device would report a language problem for what is really a hardware one.
    static func resolve(locale: Locale) -> State {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            return .unavailable(mapped(reason))
        @unknown default:
            // A reason the framework grew after this was written. Falling back to Tier 1 is
            // always safe, so an unrecognised state is not a crash.
            return .unavailable(.deviceNotEligible)
        }

        guard model.supportsLocale(locale) else {
            return .unavailable(.unsupportedLanguage)
        }
        return .available
    }

    private static func mapped(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> ModelUnavailableReason {
        switch reason {
        case .deviceNotEligible: .deviceNotEligible
        case .appleIntelligenceNotEnabled: .appleIntelligenceNotEnabled
        case .modelNotReady: .modelNotReady
        @unknown default: .deviceNotEligible
        }
    }
}
