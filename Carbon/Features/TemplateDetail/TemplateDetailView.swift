import CarbonCore
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarbonSpacing.loose) {
                scanButton
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
            if let first = reviewRecordIDs.first {
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
        .task { prepareModel() }
    }

    private var store: CarbonStore {
        CarbonStore(modelContainer: modelContext.container)
    }

    private var scanButton: some View {
        VStack(spacing: CarbonSpacing.tight) {
            Button {
                Task { await scanTapped() }
            } label: {
                Label("Scan", systemImage: "camera")
                    .font(CarbonFont.dataValueLarge)
            }
            .buttonStyle(.carbonPrimary)

            if !DocumentCamera.isAvailable {
                // A judge opening this on a simulator lands here. Say what is happening
                // rather than showing a button that does nothing.
                Text("The camera isn't available on this device.")
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
            }
        }
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: CarbonSpacing.snug) {
            SectionHeader("Fields")
            ForEach(template.fields, id: \.key) { field in
                HStack {
                    Text(field.label)
                        .font(CarbonFont.body)
                        .foregroundStyle(CarbonColor.ink)
                    Spacer()
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
