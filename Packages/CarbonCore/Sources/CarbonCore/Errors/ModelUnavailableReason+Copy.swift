import Foundation

/// Copy for the on-device intelligence status line in Settings.
///
/// This is never an alert and never interrupts a scan. Extraction has already carried on
/// without the model and produced a usable result — this line exists so someone who wonders
/// why a form took more correcting than usual can find out, not to ask them to fix anything.
///
/// Note the vocabulary: "on-device intelligence", never "AI", never "the model".
extension ModelUnavailableReason {
    public var settingsTitle: LocalizedStringResource {
        LocalizedStringResource(
            "model_unavailable.title",
            defaultValue: "On-device intelligence is off.",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    public var settingsGuidance: LocalizedStringResource {
        switch self {
        case .deviceNotEligible:
            LocalizedStringResource(
                "model_unavailable.device_not_eligible.guidance",
                defaultValue: "This device reads forms by matching the page layout. Everything works.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .appleIntelligenceNotEnabled:
            LocalizedStringResource(
                "model_unavailable.not_enabled.guidance",
                defaultValue: """
                    Carbon is reading forms by matching the page layout. Turn on Apple \
                    Intelligence in Settings to also fill in fields it can't place.
                    """,
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .modelNotReady:
            LocalizedStringResource(
                "model_unavailable.not_ready.guidance",
                defaultValue: "Still downloading. Carbon is matching the page layout meanwhile.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .unsupportedLanguage:
            LocalizedStringResource(
                "model_unavailable.unsupported_language.guidance",
                defaultValue: "Your language isn't covered yet. Carbon is matching the page layout.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        }
    }
}
