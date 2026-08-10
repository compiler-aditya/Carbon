import CarbonCore
import SwiftUI

/// Creates a template: name it, pick a mode, declare its fields.
///
/// The mode picker explains itself under the selection rather than assuming "record" and
/// "table" mean anything to someone holding a paper register.
struct TemplateEditorView: View {
    let store: CarbonStore

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var subtitle = ""
    @State private var mode: TemplateMode = .table
    @State private var fields: [NewFieldSpec] = []
    @State private var newFieldLabel = ""
    @State private var newFieldType: FieldType = .text
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Daily Register", text: $name)
                    TextField("What it's for (optional)", text: $subtitle)
                }

                Section("Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("Record").tag(TemplateMode.record)
                        Text("Table").tag(TemplateMode.table)
                    }
                    .pickerStyle(.segmented)

                    Text(modeExplanation)
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                }

                Section("Fields") {
                    ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                        HStack {
                            Text(field.label)
                            Spacer()
                            Text(field.type.rawValue)
                                .font(CarbonFont.caption)
                                .foregroundStyle(CarbonColor.inkMuted)
                        }
                    }
                    .onDelete { fields.remove(atOffsets: $0) }
                    .onMove { fields.move(fromOffsets: $0, toOffset: $1) }

                    addFieldRow
                }

                if let reason = blockingReason {
                    Section {
                        // Say why Save is unavailable. A disabled button with no explanation
                        // is a dead end the user cannot reason about.
                        Text(reason)
                            .font(CarbonFont.caption)
                            .foregroundStyle(CarbonColor.inkMuted)
                    }
                }
            }
            .navigationTitle("New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(blockingReason != nil || isSaving)
                }
                // Only worth showing once there is something to reorder or delete.
                if !fields.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
            }
        }
    }

    private var addFieldRow: some View {
        HStack(spacing: CarbonSpacing.tight) {
            TextField("Add a field", text: $newFieldLabel)
                .onSubmit(addField)

            Picker("Type", selection: $newFieldType) {
                ForEach(FieldType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .labelsHidden()

            // .borderless is load-bearing: inside a Form row SwiftUI otherwise makes the
            // whole row one tap target, and a tap on Add lands on the text field instead.
            Button("Add", action: addField)
                .buttonStyle(.borderless)
                .disabled(newFieldLabel.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var modeExplanation: String {
        switch mode {
        case .record:
            String(localized: "One photo of the form becomes one row. An intake form, a job card.")
        case .table:
            String(localized: "One photo becomes a row per line on the page. A register, a log sheet.")
        }
    }

    private var blockingReason: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(localized: "Give the template a name to save it.")
        }
        if fields.isEmpty {
            return String(localized: "Add at least one field so Carbon knows what to read.")
        }
        return nil
    }

    private func addField() {
        let label = newFieldLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        fields.append(NewFieldSpec(label: label, type: newFieldType))
        newFieldLabel = ""
        newFieldType = .text
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        try? await store.createTemplate(
            name: name.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            mode: mode,
            symbolName: mode == .table ? "tablecells" : "doc.text",
            fields: fields
        )
        dismiss()
    }
}
