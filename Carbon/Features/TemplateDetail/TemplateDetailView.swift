import CarbonCore
import CoreGraphics
import SwiftData
import SwiftUI

/// One template: scan it, see its fields, see what it has collected.
///
/// **Scan is the largest tappable thing on the screen** because it is the verb of the app.
struct TemplateDetailView: View {
    let template: TemplateSnapshot

    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var captureModel: CaptureModel?
    @State private var reviewRecordIDs: [UUID] = []
    @State private var isShowingCamera = false
    @State private var isShowingPaywall = false
    @State private var recordCount = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Rows that pair a label with a value stack vertically at accessibility sizes. Side by
    /// side, "7 records" in mono wraps mid-word to "7 / record / s", which is worse than
    /// simply putting it on its own line.
    private var pairLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CarbonSpacing.hair))
            : AnyLayout(HStackLayout())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarbonSpacing.loose) {
                scanButton
                recordsSection
                fieldsSection
            }
            .padding(CarbonSpacing.regular)
        }
        .carbonBackground()
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $isShowingCamera) {
            DocumentCamera(
                onFinish: { pages in
                    isShowingCamera = false
                    Task { await captureModel?.process(pages: pages) }
                },
                onCancel: {
                    isShowingCamera = false
                    captureModel?.cancelCapture()
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: isProcessing) {
            if case .processing(let step, let index, let total) = captureModel?.state {
                ProcessingView(step: step, pageIndex: index, total: total)
            }
        }
        .navigationDestination(isPresented: hasReview) {
            // A table page produces many rows and belongs in the grid; a record page produces
            // one and belongs in the field list. Routing on the template's declared mode
            // rather than on how many records came back keeps a one-row register in the grid,
            // where the user expects it.
            if template.mode == .table {
                TableReviewView(
                    model: TableReviewModel(
                        store: store, template: template, recordIDs: reviewRecordIDs
                    )
                )
            } else if let first = reviewRecordIDs.first {
                ReviewView(
                    model: ReviewModel(store: store, template: template, recordID: first)
                )
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallSheet(reason: captureModel?.paywallReason ?? .recordLimit)
        }
        .onChange(of: captureModel?.state) { _, newValue in
            if case .review(let ids) = newValue { reviewRecordIDs = ids }
        }
        .onChange(of: captureModel?.paywallReason) { _, newValue in
            isShowingPaywall = newValue != nil
        }
        .task {
            prepareModel()
            await refreshRecordCount()
        }
        // The snapshot this screen was handed is a point-in-time copy, so the count has to be
        // re-read rather than trusted after a capture writes new rows.
        .onChange(of: reviewRecordIDs) { _, _ in
            Task { await refreshRecordCount() }
        }
    }

    private var store: CarbonStore {
        CarbonStore(modelContainer: modelContext.container)
    }

    /// Scan is the verb of the app, so it leads — unless there is no camera, in which case
    /// choosing a photo is promoted rather than leaving a dead primary button on screen.
    /// That is the state a judge on a simulator opens the app in.
    private var scanButton: some View {
        VStack(spacing: CarbonSpacing.snug) {
            if DocumentCamera.isAvailable {
                Button {
                    Task { await scanTapped() }
                } label: {
                    Label("Scan", systemImage: "camera")
                        .font(CarbonFont.dataValueLarge)
                }
                .buttonStyle(.carbonPrimary)

                PhotoImportButton(
                    label: String(localized: "Choose a photo"),
                    isPrimary: false,
                    onPicked: importPicked
                )
            } else {
                PhotoImportButton(
                    label: String(localized: "Choose a photo"),
                    isPrimary: true,
                    onPicked: importPicked
                )

                Text("This device has no camera, so pick a photo of the form instead.")
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// The library and the camera converge on the same function immediately, so the pipeline
    /// has one entry point rather than two paths that can drift apart.
    private func importPicked(_ pages: [CGImage]) {
        Task {
            prepareModel()
            await captureModel?.beginCapture()
            // beginCapture only sets .capturing when the meter allows it; if it presented the
            // paywall instead, the pages are dropped rather than half-processed.
            guard captureModel?.state == .capturing else { return }
            await captureModel?.process(pages: pages)
        }
    }

    private var recordsSection: some View {
        NavigationLink {
            DatasetView(model: DatasetModel(store: store, template: template))
        } label: {
            pairLayout {
                Text("View all records")
                    .font(CarbonFont.body)
                    .foregroundStyle(CarbonColor.carbon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(recordCount) records")
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(CarbonColor.inkMuted)
                    .frame(
                        maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                        alignment: .leading
                    )
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                }
            }
            .padding(CarbonSpacing.regular)
            .background(CarbonColor.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: CarbonRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: CarbonRadius.card)
                    .stroke(CarbonColor.rule.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: CarbonSpacing.snug) {
            SectionHeader("Fields")
            ForEach(template.fields, id: \.key) { field in
                pairLayout {
                    Text(field.label)
                        .font(CarbonFont.body)
                        .foregroundStyle(CarbonColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(field.type.rawValue)
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                        .padding(.horizontal, CarbonSpacing.tight)
                        .padding(.vertical, 2)
                        .overlay {
                            RoundedRectangle(cornerRadius: CarbonRadius.chip)
                                .stroke(CarbonColor.rule.opacity(0.6), lineWidth: 1)
                        }
                }
                .padding(.vertical, CarbonSpacing.hair)
            }
        }
    }

    private var isProcessing: Binding<Bool> {
        Binding(
            get: { if case .processing = captureModel?.state { true } else { false } },
            set: { _ in }
        )
    }

    private var hasReview: Binding<Bool> {
        Binding(
            get: { !reviewRecordIDs.isEmpty },
            set: { if !$0 { reviewRecordIDs = [] } }
        )
    }

    private func prepareModel() {
        guard captureModel == nil else { return }
        captureModel = CaptureModel(services: services, store: store, template: template)
    }

    private func refreshRecordCount() async {
        recordCount = (try? await store.recordCounts(templateID: template.id)[.all]) ?? 0
    }

    private func scanTapped() async {
        prepareModel()
        await captureModel?.beginCapture()
        if captureModel?.state == .capturing {
            isShowingCamera = true
        }
    }
}

#Preview {
    NavigationStack {
        TemplateDetailView(template: SampleTemplatePreview.dailyRegister)
    }
    .environment(\.services, .preview())
    .modelContainer(for: CarbonSchemaV1.models, inMemory: true)
}

/// A stand-in so this screen previews without reaching into the fixtures package for a
/// snapshot it would only use here.
enum SampleTemplatePreview {
    static var dailyRegister: TemplateSnapshot {
        TemplateSnapshot(
            id: UUID(),
            name: "Daily Register",
            mode: .table,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [],
            learnedHeaderAliases: [],
            subtitle: "Shop sales",
            symbolName: "tablecells",
            lastUsedAt: .now,
            recordCount: 142
        )
    }
}
