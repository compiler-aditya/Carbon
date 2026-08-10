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
    @Query(sort: \FormTemplate.lastUsedAt, order: .reverse)
    private var templates: [FormTemplate]

    var body: some View {
        TabView {
            Tab("Templates", systemImage: "doc.text") {
                NavigationStack {
                    templateList
                        .navigationTitle("Templates")
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
        }
    }

    @ViewBuilder
    private var templateList: some View {
        if templates.isEmpty {
            ContentUnavailableView {
                Label("No templates yet.", systemImage: "doc.text")
            } description: {
                Text(
                    "A template teaches Carbon the shape of one paper form. "
                        + "You'll only do this once per form."
                )
            }
        } else {
            List(templates) { template in
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                    Text("\(template.recordCount) records")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
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
