import CarbonCore
import Observation
import SwiftUI

/// Which records go into the file.
enum ExportScope: String, CaseIterable, Identifiable {
    case all
    case confirmedOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All records")
        case .confirmedOnly: String(localized: "Skip anything needing review")
        }
    }
}

@MainActor
@Observable
final class ExportModel {
    private(set) var records: [RecordSnapshot] = []
    private(set) var fileURL: URL?
    private(set) var failure: CarbonError?

    var scope: ExportScope = .all { didSet { Task { await load() } } }

    let template: TemplateSnapshot
    private let store: CarbonStore
    private let exporter: any Exporting

    init(store: CarbonStore, exporter: any Exporting, template: TemplateSnapshot) {
        self.store = store
        self.exporter = exporter
        self.template = template
    }

    func load() async {
        let query = RecordQuery(
            templateID: template.id,
            filter: scope == .confirmedOnly ? .confirmed : .all,
            sort: .oldest
        )
        records = (try? await store.records(matching: query)) ?? []
        fileURL = nil
    }

    /// Writes the file and logs the export.
    ///
    /// Written to a temporary file rather than shared as an in-memory document, so the share
    /// sheet hands other apps a real file with a real name — "Daily Register 2026-08-11.csv"
    /// in Files, not "Untitled".
    func prepareFile() async {
        do {
            let data = try exporter.csv(records: records, template: template)
            let name = CSVExporter.fileName(for: template)
            let url = FileManager.default.temporaryDirectory.appending(path: name)
            try data.write(to: url, options: .atomic)

            try? await store.logExport(
                templateID: template.id, recordCount: records.count, fileName: name
            )
            fileURL = url
            failure = nil
        } catch {
            // Through the taxonomy rather than a string written here, so this sentence and
            // the one an error sheet would show can never drift apart.
            failure = .exportFailed(underlying: String(describing: error))
        }
    }
}

/// A small sheet, not a screen: choose what goes in, see how much, hand it to the share sheet.
struct ExportSheet: View {
    @State var model: ExportModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    LabeledContent("CSV", value: "\(model.records.count) rows")
                        .font(CarbonFont.body)

                    // Shown greyed rather than hidden: honest about what exists today and
                    // what is on the roadmap.
                    LabeledContent("XLSX", value: String(localized: "Coming soon"))
                        .foregroundStyle(CarbonColor.inkMuted)
                }

                Section("Include") {
                    Picker("Scope", selection: $model.scope) {
                        ForEach(ExportScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                Section {
                    if let url = model.fileURL {
                        ShareLink(item: url) {
                            Label("Share \(model.records.count) records", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Prepare file") {
                            Task { await model.prepareFile() }
                        }
                        .disabled(model.records.isEmpty)
                    }

                    if let failure = model.failure {
                        VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
                            Text(String(localized: failure.title))
                                .font(CarbonFont.body)
                                .foregroundStyle(CarbonColor.stamp)
                            Text(String(localized: failure.guidance))
                                .font(CarbonFont.caption)
                                .foregroundStyle(CarbonColor.inkMuted)
                        }
                    }
                } footer: {
                    if model.records.isEmpty {
                        Text("There's nothing to export yet.")
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await model.load() }
        }
        .presentationDetents([.medium])
    }
}
