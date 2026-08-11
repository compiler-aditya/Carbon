import CarbonCore
import SwiftData
import SwiftUI

/// The root screen. Templates are the organising concept of the product, so they are the
/// first thing and everything else is reached through one.
struct TemplateListView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<FormTemplate> { !$0.isArchived },
           sort: \FormTemplate.lastUsedAt, order: .reverse)
    private var templates: [FormTemplate]

    @State private var isShowingEditor = false
    @State private var isShowingPaywall = false
    @State private var selection: TemplateSnapshot?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// A card wants a size, not a share of the screen.
    ///
    /// One column at accessibility sizes on a phone: two columns of 160pt leaves each card
    /// narrower than a single word of mono at those sizes, and "7 records" wraps to three
    /// lines. On an iPad the same 160pt minimum would lay four thin cards across 834pt, so the
    /// minimum grows with the size class and the grid settles at three in portrait — with room
    /// to become four in landscape rather than a hard-coded count that wastes the width.
    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize, horizontalSizeClass != .regular {
            return [GridItem(.flexible())]
        }
        let minimum: CGFloat =
            if horizontalSizeClass == .regular {
                dynamicTypeSize.isAccessibilitySize ? 320 : 240
            } else {
                160
            }
        return [GridItem(.adaptive(minimum: minimum), spacing: CarbonSpacing.regular)]
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .carbonBackground()
        .navigationTitle("Templates")
        .navigationDestination(item: $selection) { template in
            TemplateDetailView(template: template)
        }
        .sheet(isPresented: $isShowingEditor) {
            TemplateEditorView(store: store)
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallSheet(reason: .templateLimit)
        }
        // A shortcut may have cold-launched the app, so the request is picked up once the
        // templates have actually loaded rather than at init.
        .task(id: templates.count) { await honourPendingIntent() }
    }

    private var store: CarbonStore {
        CarbonStore(modelContainer: modelContext.container)
    }

    /// Opens the template a Siri phrase or Shortcut asked for.
    ///
    /// The request is consumed rather than observed, so re-evaluating this view does not
    /// re-open the camera.
    private func honourPendingIntent() async {
        guard let requested = CaptureIntentRouter.shared.take() else { return }
        selection = templates.first { $0.id == requested }?.snapshot
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: CarbonSpacing.regular) {
                ForEach(templates, id: \.id) { template in
                    Button {
                        selection = template.snapshot
                    } label: {
                        TemplateCard(template: template.snapshot)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await createTemplateTapped() }
                } label: {
                    NewTemplateCard(isLocked: isAtTemplateLimit)
                }
                .buttonStyle(.plain)
            }
            .padding(CarbonSpacing.regular)
        }
    }

    private var emptyState: some View {
        EmptyState(
            symbol: "doc.text",
            headline: String(localized: "No templates yet."),
            message: String(
                localized: """
                    A template teaches Carbon the shape of one paper form. \
                    You'll only do this once per form.
                    """
            )
        ) {
            Button("Create your first template") {
                Task { await createTemplateTapped() }
            }
            .buttonStyle(.carbonPrimary)
        }
    }

    private var isAtTemplateLimit: Bool {
        !services.entitlements.isPro && templates.count >= FreeTierLimit.templates
    }

    /// The gate is checked at the moment of the action, and it presents the paywall rather
    /// than an alert — a limit is a normal outcome of using the app, not a failure.
    private func createTemplateTapped() async {
        let decision = await services.meter.canCreateTemplate(
            existingCount: templates.count, isPro: services.entitlements.isPro
        )
        if case .paywall = decision {
            isShowingPaywall = true
        } else {
            isShowingEditor = true
        }
    }
}

#Preview("Empty") {
    NavigationStack { TemplateListView() }
        .environment(\.services, .preview())
        .modelContainer(for: CarbonSchemaV1.models, inMemory: true)
}
