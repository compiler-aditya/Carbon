import Foundation

/// User-facing copy for every error case.
///
/// Each case says what happened and what to do next, in the interface's voice. No apology,
/// no vagueness, and nothing about how the system works internally — the person reading this
/// wants their form scanned, not an account of the pipeline.
///
/// Defaults are inline so the package works before the catalog is translated; the catalog
/// carries the same keys and wins when present.
extension CarbonError {
    public var title: LocalizedStringResource {
        switch self {
        case .cameraUnavailable:
            LocalizedStringResource(
                "error.camera_unavailable.title",
                defaultValue: "The camera isn't available.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .cameraPermissionDenied:
            LocalizedStringResource(
                "error.camera_permission_denied.title",
                defaultValue: "Carbon doesn't have camera access.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .pageWriteFailed:
            LocalizedStringResource(
                "error.page_write_failed.title",
                defaultValue: "That page couldn't be saved.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .recognitionFailed(let pageIndex):
            LocalizedStringResource(
                "error.recognition_failed.title",
                defaultValue: "Page \(pageIndex + 1) couldn't be read.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .noTableFound:
            LocalizedStringResource(
                "error.no_table_found.title",
                defaultValue: "No table found on this page.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .noFieldsMatched:
            LocalizedStringResource(
                "error.no_fields_matched.title",
                defaultValue: "Nothing matched this template.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .modelUnavailable(let reason):
            reason.settingsTitle
        case .modelTimedOut:
            LocalizedStringResource(
                "error.model_timed_out.title",
                defaultValue: "Some fields were left for you to fill in.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .exportFailed:
            LocalizedStringResource(
                "error.export_failed.title",
                defaultValue: "The export didn't finish.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        }
    }

    public var guidance: LocalizedStringResource {
        switch self {
        case .cameraUnavailable:
            LocalizedStringResource(
                "error.camera_unavailable.guidance",
                defaultValue: "Choose a photo from your library instead.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .cameraPermissionDenied:
            LocalizedStringResource(
                "error.camera_permission_denied.guidance",
                defaultValue: "Turn on camera access in Settings to scan a form.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .pageWriteFailed:
            LocalizedStringResource(
                "error.page_write_failed.guidance",
                defaultValue: "Check how much space is left on your device, then scan again.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .recognitionFailed:
            LocalizedStringResource(
                "error.recognition_failed.guidance",
                defaultValue: "Try a straighter photo in better light.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .noTableFound:
            LocalizedStringResource(
                "error.no_table_found.guidance",
                defaultValue: """
                    This template expects a table. Try a straighter photo, or switch the \
                    template to single-record mode.
                    """,
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .noFieldsMatched:
            LocalizedStringResource(
                "error.no_fields_matched.guidance",
                defaultValue: "This may be a different form. Choose another template, or scan again.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .modelUnavailable(let reason):
            reason.settingsGuidance
        case .modelTimedOut:
            LocalizedStringResource(
                "error.model_timed_out.guidance",
                defaultValue: "They're marked for review at the top of the record.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        case .exportFailed:
            LocalizedStringResource(
                "error.export_failed.guidance",
                defaultValue: "Try again, or export a smaller range of records.",
                bundle: .atURL(Bundle.module.bundleURL)
            )
        }
    }
}
