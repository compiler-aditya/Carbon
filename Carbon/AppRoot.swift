import CarbonCore
import CarbonTestFixtures
import SwiftData
import SwiftUI

/// Root navigation. Two tabs — Templates and Settings — because the template is the
/// organising concept of the product and the navigation should teach that. Datasets are
/// reached through a template, never alongside it.
///
/// The real screens land next; this is the shell that proves the wiring.
struct AppRoot: View {
    var body: some View {
        TabView {
            Tab("Templates", systemImage: "doc.text") {
                NavigationStack { TemplateListView() }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView().navigationTitle("Settings")
                }
            }
        }
        .tint(CarbonColor.carbon)
        .carbonTypeSize()
    }
}

#Preview("Empty") {
    AppRoot()
        .environment(\.services, .preview())
        .modelContainer(for: CarbonSchemaV1.models, inMemory: true)
}

#Preview("With templates") {
    AppRoot()
        .environment(\.services, .previewPro())
        .modelContainer(PreviewData.container)
}

/// Seeds an in-memory container so the populated preview shows realistic content rather than
/// an empty list.
private enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Schema.carbon,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        for sample in SampleTemplates.all {
            let template = FormTemplate()
            template.id = sample.id
            template.name = sample.name
            template.mode = sample.mode
            template.lastUsedAt = .now
            container.mainContext.insert(template)
        }
        return container
    }()
}
