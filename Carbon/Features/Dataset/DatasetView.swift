import CarbonCore
import Observation
import SwiftUI

@MainActor
@Observable
final class DatasetModel {
    private(set) var records: [RecordSnapshot] = []
    private(set) var counts: [RecordFilter: Int] = [:]

    var searchText = "" { didSet { reloadSoon() } }
    var filter: RecordFilter = .all { didSet { reloadSoon() } }
    var sort: RecordSort = .newest { didSet { reloadSoon() } }

    let template: TemplateSnapshot
    private let store: CarbonStore
    private var reloadTask: Task<Void, Never>?

    init(store: CarbonStore, template: TemplateSnapshot) {
        self.store = store
        self.template = template
    }

    func load() async {
        let query = RecordQuery(
            templateID: template.id, filter: filter, searchText: searchText, sort: sort
        )
        records = (try? await store.records(matching: query)) ?? []
        counts = (try? await store.recordCounts(templateID: template.id)) ?? [:]
    }

    /// Coalesces the reloads a keystroke storm would otherwise cause. Without it, typing
    /// "mustard" runs seven queries and the last one to finish wins, which is not necessarily
    /// the one the user is waiting for.
    private func reloadSoon() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    func delete(_ record: RecordSnapshot, pageStore: any PageStoring) async {
        try? await store.deleteRecord(id: record.id, pageStore: pageStore)
        await load()
    }
}

/// Everything one template has collected.
struct DatasetView: View {
    @State var model: DatasetModel

    @Environment(\.services) private var services
    @State private var isShowingPaywall = false
    @State private var isShowingExport = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if model.records.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .carbonBackground()
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.searchText, prompt: "Search values")
        .safeAreaInset(edge: .top) { filterChips }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { sortMenu }
            ToolbarItem(placement: .topBarTrailing) { exportButton }
        }
        .sheet(isPresented: $isShowingPaywall) { PaywallSheet(reason: .export) }
        .sheet(isPresented: $isShowingExport) {
            ExportSheet(
                model: ExportModel(
                    store: CarbonStore(modelContainer: modelContext.container),
                    exporter: services.exporter,
                    template: model.template
                )
            )
        }
        // The purchase edge case that matters most: when entitlement flips to Pro, the export
        // the user originally asked for opens by itself. Making them tap Export a second time
        // after paying for it is the single most avoidable insult in a paywall flow.
        .onChange(of: services.entitlements.isPro) { wasPro, isPro in
            if !wasPro, isPro, isShowingPaywall {
                isShowingPaywall = false
                isShowingExport = true
            }
        }
        .onAppear { Task { await model.load() } }
    }

    private var list: some View {
        List {
            ForEach(model.records, id: \.id) { record in
                // A dataset you cannot open is a dead end: a value spotted as wrong here has
                // no route to being fixed. Every row leads to the same review screen a fresh
                // capture does, so correcting an old record works exactly like correcting a
                // new one. One record is a field list even for a table template — the grid is
                // for reviewing a whole page at once, not for revisiting a single row.
                NavigationLink {
                    ReviewView(
                        model: ReviewModel(
                            store: CarbonStore(modelContainer: modelContext.container),
                            template: model.template,
                            recordID: record.id
                        )
                    )
                } label: {
                    RecordRow(template: model.template, record: record)
                }
                .listRowBackground(CarbonColor.paperRaised)
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        Task { await model.delete(record, pageStore: services.pageStore) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // A correction made in there changes a status and a count out here.
        .refreshable { await model.load() }
    }

    /// Chips carry their counts, so the shape of the dataset is visible without tapping
    /// through each one.
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CarbonSpacing.tight) {
                ForEach(RecordFilter.allCases, id: \.self) { filter in
                    let isSelected = model.filter == filter
                    Button {
                        model.filter = filter
                    } label: {
                        Text("\(title(for: filter)) \(model.counts[filter] ?? 0)")
                            .font(CarbonFont.caption)
                            .foregroundStyle(isSelected ? CarbonColor.paperRaised : CarbonColor.ink)
                            .padding(.horizontal, CarbonSpacing.snug)
                            .padding(.vertical, CarbonSpacing.hair + 2)
                            .background(isSelected ? CarbonColor.carbon : CarbonColor.carbonSoft)
                            .clipShape(RoundedRectangle(cornerRadius: CarbonRadius.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CarbonSpacing.regular)
            .padding(.vertical, CarbonSpacing.tight)
        }
        .background(CarbonColor.paper)
    }

    private var sortMenu: some View {
        Menu {
            Button("Newest first") { model.sort = .newest }
            Button("Oldest first") { model.sort = .oldest }
            Divider()
            ForEach(model.template.fields, id: \.key) { field in
                Button("By \(field.label)") { model.sort = .field(key: field.key) }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    /// Always visible, with a lock when it is not available. Gate the outcome, not the
    /// discoverability — a hidden Export teaches nobody that Carbon exports.
    private var exportButton: some View {
        Button {
            // Gate at the moment of the action. Export is the honest paywall: the work is
            // already done and visible on screen, and Pro is for taking it with you.
            if services.entitlements.isPro {
                isShowingExport = true
            } else {
                isShowingPaywall = true
            }
        } label: {
            Label("Export", systemImage: services.entitlements.isPro ? "square.and.arrow.up" : "lock")
        }
    }

    private var emptyState: some View {
        EmptyState(
            symbol: model.searchText.isEmpty ? "tray" : "magnifyingglass",
            headline: model.searchText.isEmpty
                ? String(localized: "No records yet.")
                : String(localized: "Nothing matched."),
            message: model.searchText.isEmpty
                ? String(localized: "Scan the form and the rows land here.")
                : String(localized: "Try a different search, or clear it to see everything.")
        ) {
            EmptyView()
        }
    }

    private func title(for filter: RecordFilter) -> String {
        switch filter {
        case .all: String(localized: "All")
        case .needsReview: String(localized: "Needs review")
        case .confirmed: String(localized: "Confirmed")
        }
    }
}

/// One dataset row: the first few values in mono, a status dot, and when it was captured.
struct RecordRow: View {
    let template: TemplateSnapshot
    let record: RecordSnapshot

    /// Scales with the text beside it — a fixed 7pt dot is a speck next to accessibility type.
    @ScaledMetric(relativeTo: .caption) private var statusSize: CGFloat = 11

    var body: some View {
        HStack(spacing: CarbonSpacing.snug) {
            // Shape carries the status, not only colour. A red dot and a green dot are the
            // same dot to a colour-blind reader, and this app's own rule is that status is
            // never conveyed by colour alone.
            Image(
                systemName: record.status == .needsReview
                    ? "exclamationmark.circle.fill" : "checkmark.circle"
            )
            .font(.system(size: statusSize))
            .foregroundStyle(
                record.status == .needsReview ? CarbonColor.stamp : CarbonColor.confirm
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryValues)
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(CarbonColor.ink)
                    .lineLimit(1)
                Text(record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
            }
            Spacer()
        }
        .padding(.vertical, CarbonSpacing.hair)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(primaryValues), \(record.status == .needsReview ? "needs review" : "confirmed")"
        )
    }

    /// Up to three fields, so a row identifies itself without becoming a wall of text.
    private var primaryValues: String {
        template.fields
            .prefix(3)
            .map { record.exportValue(forKey: $0.key) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
    }
}
