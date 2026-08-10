import AppIntents
import CarbonCore
import SwiftData

/// "Hey Siri, capture Daily Register."
///
/// Opens the app on that template's capture flow. Deliberately `openAppWhenRun` rather than a
/// background intent: capture needs the camera and a person pointing it at a page, so
/// pretending it can happen without the app in front of them would be a lie the shortcut
/// tells on the app's behalf.
struct CaptureFromTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture a form"
    static let description = IntentDescription(
        "Opens Carbon's camera on one of your templates.",
        categoryName: "Capture"
    )

    static let openAppWhenRun = true

    @Parameter(title: "Template")
    var template: TemplateEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureIntentRouter.shared.request(templateID: template.id)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$template)")
    }
}

/// A template, as Shortcuts sees it.
struct TemplateEntity: AppEntity {
    let id: UUID
    let name: String
    let subtitle: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Template"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)"
        )
    }

    static var defaultQuery: TemplateQuery { TemplateQuery() }
}

/// Answers Shortcuts' questions about which templates exist.
struct TemplateQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [TemplateEntity] {
        try await all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TemplateEntity] {
        // Most recently used first, so the template someone actually scans daily is the one
        // Shortcuts offers first.
        try await all()
    }

    @MainActor
    private func all() async throws -> [TemplateEntity] {
        let container = try ModelContainer(
            for: Schema.carbon, migrationPlan: CarbonMigrationPlan.self
        )
        let store = CarbonStore(modelContainer: container)
        return try await store.templateSnapshots().map {
            TemplateEntity(id: $0.id, name: $0.name, subtitle: $0.subtitle)
        }
    }
}

/// Carries an intent's request from the App Intents runtime into the running UI.
///
/// The intent and the view hierarchy have no other way to meet: `perform()` runs outside any
/// view, and the app may have been cold-launched by the shortcut. A tiny observable box is
/// less machinery than a notification and is visible to anyone reading the navigation code.
@MainActor
@Observable
final class CaptureIntentRouter {
    static let shared = CaptureIntentRouter()

    private(set) var pendingTemplateID: UUID?

    private init() {}

    func request(templateID: UUID) {
        pendingTemplateID = templateID
    }

    /// Consumed once. A request that survived being handled would re-open the camera every
    /// time the root view re-evaluated.
    func take() -> UUID? {
        defer { pendingTemplateID = nil }
        return pendingTemplateID
    }
}

struct CarbonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureFromTemplateIntent(),
            phrases: [
                "Capture a form with \(.applicationName)",
                "Scan a form with \(.applicationName)",
                "New \(.applicationName) record",
            ],
            shortTitle: "Capture",
            systemImageName: "camera"
        )
    }
}
