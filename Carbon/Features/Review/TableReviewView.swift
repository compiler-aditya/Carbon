import CarbonCore
import Observation
import SwiftUI

@MainActor
@Observable
final class TableReviewModel {
    private(set) var records: [RecordSnapshot] = []

    let template: TemplateSnapshot
    private let store: CarbonStore
    private let recordIDs: [UUID]

    init(store: CarbonStore, template: TemplateSnapshot, recordIDs: [UUID]) {
        self.store = store
        self.template = template
        self.recordIDs = recordIDs
    }

    /// Cells below the threshold, across every row. The number the header reports, and the
    /// reason this screen exists.
    var cellsNeedingReview: Int {
        records.reduce(0) { total, record in
            total + template.fields.count { field in
                (record.value(forKey: field.key)?.band ?? .needsReview) == .needsReview
            }
        }
    }

    func load() async {
        let all = (try? await store.records(matching: RecordQuery(templateID: template.id))) ?? []
        let wanted = Set(recordIDs)
        // Keep the page's own order — row 1 on the paper is row 1 here.
        records = all.filter { wanted.contains($0.id) }
            .sorted { ($0.sourceRowIndex ?? 0) < ($1.sourceRowIndex ?? 0) }
    }

    func correct(record: RecordSnapshot, field: FieldSnapshot, to newValue: String) async {
        try? await store.applyCorrection(
            recordID: record.id, fieldKey: field.key, newValue: newValue
        )
        await load()
    }

    func confirmAll() async {
        try? await store.confirmRecords(ids: records.map(\.id))
        await load()
    }
}

/// Table-mode review: every row the page produced, in one grid.
struct TableReviewView: View {
    @State var model: TableReviewModel
    @State private var editing: (record: RecordSnapshot, field: FieldSnapshot)?
    @State private var draftValue = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            CellGrid(template: model.template, records: model.records) { record, field in
                draftValue = record.value(forKey: field.key)?.normalizedValue ?? ""
                editing = (record, field)
            }
        }
        .carbonBackground()
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .sheet(isPresented: isEditing) {
            if let editing {
                CellEditor(
                    field: editing.field,
                    rawText: editing.record.value(forKey: editing.field.key)?.rawText,
                    value: $draftValue
                ) { newValue in
                    let target = editing
                    self.editing = nil
                    Task { await model.correct(record: target.record, field: target.field, to: newValue) }
                } onCancel: {
                    self.editing = nil
                }
            }
        }
    }

    /// States the outcome in the app's own voice: what it found, and how much of it wants a
    /// look. Never "AI found", never a percentage nobody can act on.
    private var header: some View {
        HStack {
            Text("\(model.records.count) rows found")
                .font(CarbonFont.dataValue)
                .foregroundStyle(CarbonColor.ink)
            if model.cellsNeedingReview > 0 {
                Text("·")
                    .foregroundStyle(CarbonColor.inkMuted)
                Text("\(model.cellsNeedingReview) cells need review")
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(CarbonColor.stamp)
            }
            Spacer()
        }
        .padding(.horizontal, CarbonSpacing.regular)
        .padding(.vertical, CarbonSpacing.snug)
    }

    private var bottomBar: some View {
        Button("Save \(model.records.count) records") {
            Task {
                await model.confirmAll()
                dismiss()
            }
        }
        .buttonStyle(.carbonPrimary)
        .padding(CarbonSpacing.regular)
        .background(CarbonColor.paperRaised)
        .overlay(alignment: .top) {
            Rectangle().fill(CarbonColor.rule.opacity(0.5)).frame(height: 1)
        }
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }
}

/// Shared cell editor. Opens the keyboard the field's declared type calls for and shows what
/// was read off the page, so a correction stays an informed one.
struct CellEditor: View {
    let field: FieldSnapshot
    let rawText: String?
    @Binding var value: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if field.type == .choice, !field.choices.isEmpty {
                        Picker(field.label, selection: $value) {
                            ForEach(field.choices, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.inline)
                    } else {
                        TextField(field.label, text: $value)
                            .font(CarbonFont.dataValue)
                            .keyboardType(keyboardType)
                            .autocorrectionDisabled(field.type == .identifier)
                    }
                } header: {
                    Text(field.label)
                } footer: {
                    if let rawText, !rawText.isEmpty {
                        Text("Read from the page as \(rawText)")
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(value) }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var keyboardType: UIKeyboardType {
        switch field.type {
        case .integer: .numberPad
        case .decimal, .currency: .decimalPad
        case .phone: .phonePad
        default: .default
        }
    }
}
