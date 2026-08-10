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
    /// Shown once. Skipping counts as seeing it — someone who skipped does not want it again.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var isInstallingSample = false

    var body: some View {
        if hasSeenOnboarding {
            tabs
        } else {
            OnboardingView(
                onCreateOwn: { hasSeenOnboarding = true },
                onUseSample: { sample in Task { await install(sample) } },
                onSkip: { hasSeenOnboarding = true }
            )
            .overlay {
                if isInstallingSample {
                    ProcessingView(step: .reading, pageIndex: 0, total: 1)
                }
            }
        }
    }

    /// Runs the real pipeline over the bundled photograph, then drops the user into the app
    /// with a template and a dataset already in it.
    private func install(_ sample: SampleFormLibrary.Sample) async {
        isInstallingSample = true
        defer {
            isInstallingSample = false
            hasSeenOnboarding = true
        }
        _ = try? await SampleFormInstaller.install(
            sample,
            services: services,
            store: CarbonStore(modelContainer: modelContext.container)
        )
    }

    private var tabs: some View {
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
