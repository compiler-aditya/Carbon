import CarbonCore
import CoreGraphics
import PhotosUI
import SwiftUI

/// Creates a template: name it, pick a mode, declare its fields.
///
/// The mode picker explains itself under the selection rather than assuming "record" and
/// "table" mean anything to someone holding a paper register.
struct TemplateEditorView: View {
    let store: CarbonStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services

    @State private var name = ""
    @State private var subtitle = ""
    @State private var mode: TemplateMode = .table
    @State private var fields: [NewFieldSpec] = []
    @State private var newFieldLabel = ""
    @State private var newFieldType: FieldType = .text
    @State private var isSaving = false
    @State private var saveError: CarbonError?
    @FocusState private var isAddFieldFocused: Bool

    /// The assist: read the columns off a photograph of the form instead of typing them.
    @State private var detected: [DetectedColumn] = []
    @State private var isReading = false
    @State private var readFailure: CarbonError?
    @State private var isShowingCamera = false

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

                if mode == .table {
                    assistSection
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

                // Shown in place rather than as a second sheet, so the work the user just
                // typed stays on screen and Save is still one tap away.
                if let saveError {
                    Section {
                        VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
                            Text(String(localized: saveError.title))
                                .font(CarbonFont.body)
                                .foregroundStyle(CarbonColor.stamp)
                            Text(String(localized: saveError.guidance))
                                .font(CarbonFont.caption)
                                .foregroundStyle(CarbonColor.inkMuted)
                        }
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
            .fullScreenCover(isPresented: $isShowingCamera) {
                DocumentCamera(
                    onFinish: { pages in
                        isShowingCamera = false
                        Task { await read(pages) }
                    },
                    onCancel: { isShowingCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    /// Read the form instead of describing it.
    ///
    /// Table mode only, because it needs a header row to read; a record form has labels beside
    /// values rather than above columns, and guessing fields from those is a different problem.
    @ViewBuilder
    private var assistSection: some View {
        Section("From the form") {
            if detected.isEmpty {
                if DocumentCamera.isAvailable {
                    Button("Scan the blank form") { isShowingCamera = true }
                        .disabled(isReading)
                }
                PhotoImportButton(
                    label: String(localized: "Choose a photo of the form"),
                    isPrimary: false,
                    onPicked: { pages in Task { await read(pages) } },
                    onFailed: { readFailure = $0 }
                )
                .buttonStyle(.borderless)

                if isReading {
                    Text("Reading the columns…")
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                } else {
                    Text("Carbon reads the headings and sets the fields up for you.")
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                }
            } else {
                // The count is in the button because it is the whole promise: the user can see
                // what they are accepting before they accept it.
                Button("Use detected columns — \(detected.count) found") { acceptDetected() }
                    .buttonStyle(.borderless)

                ForEach(detected, id: \.label) { column in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(column.label).font(CarbonFont.body)
                            Spacer()
                            Text(column.type.rawValue)
                                .font(CarbonFont.caption)
                                .foregroundStyle(CarbonColor.inkMuted)
                        }
                        if !column.samples.isEmpty {
                            // Showing what the guess was made from is the same honesty the
                            // review screen runs on: the type is a guess, and here is the
                            // evidence for it.
                            Text(column.samples.joined(separator: "  ·  "))
                                .font(CarbonFont.caption)
                                .foregroundStyle(CarbonColor.inkMuted)
                                .lineLimit(1)
                        }
                    }
                }

                // Not destructive: nothing is lost by reading another photo, and red here
                // reads as a warning about an action that carries no risk at all.
                Button("Read a different photo") { detected = [] }
                    .buttonStyle(.borderless)
            }

            if let readFailure {
                VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
                    Text(String(localized: readFailure.title))
                        .font(CarbonFont.body)
                        .foregroundStyle(CarbonColor.stamp)
                    Text(String(localized: readFailure.guidance))
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                }
            }
        }
    }

    /// Runs recognition only — no extraction, because there is no template yet to extract
    /// against. That is the whole point of this screen.
    private func read(_ pages: [CGImage]) async {
        guard let image = pages.first else { return }
        isReading = true
        readFailure = nil
        defer { isReading = false }

        do {
            let page = try await services.recognizer.recognize(image, pageID: UUID())
            let columns = ColumnDetector.columns(in: page)
            guard !columns.isEmpty else {
                readFailure = .noTableFound
                return
            }
            detected = columns
        } catch let error as CarbonError {
            readFailure = error
        } catch {
            readFailure = .recognitionFailed(pageIndex: 0)
        }
    }

    /// Appends rather than replaces, so a user who typed two fields first does not lose them.
    /// Columns already present by label are skipped instead of duplicated.
    private func acceptDetected() {
        let existing = Set(fields.map { $0.label.lowercased() })
        fields.append(
            contentsOf: detected
                .filter { !existing.contains($0.label.lowercased()) }
                .map {
                    NewFieldSpec(label: $0.label, type: $0.type, columnAliases: [$0.alias])
                }
        )
        detected = []
    }

    private var addFieldRow: some View {
        HStack(spacing: CarbonSpacing.tight) {
            TextField("Add a field", text: $newFieldLabel)
                .focused($isAddFieldFocused)
                .submitLabel(.next)
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

        // Setting up a register means declaring four or five fields in a row. Handing focus
        // straight back turns that into continuous typing instead of a tap between each one.
        isAddFieldFocused = true
    }

    /// Dismisses only on success. Closing the sheet on a failed write would look exactly like
    /// a save, and the template the user just described would simply not be there.
    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            try await store.createTemplate(
                name: name.trimmingCharacters(in: .whitespaces),
                subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                mode: mode,
                symbolName: mode == .table ? "tablecells" : "doc.text",
                fields: fields
            )
            dismiss()
        } catch {
            saveError = .saveFailed(underlying: String(describing: error))
        }
    }
}
