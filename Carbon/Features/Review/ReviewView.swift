import CarbonCore
import SwiftUI

/// Record-mode review: what Carbon read, what it is unsure about, and one tap to fix it.
///
/// This screen is the product's honesty made visible, which is why the confidence rules are
/// the loudest thing on it and everything else stays quiet.
struct ReviewView: View {
    @State var model: ReviewModel
    @State private var editingField: FieldSnapshot?
    @State private var draftValue = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, CarbonSpacing.regular)
                    .padding(.bottom, CarbonSpacing.regular)

                ForEach(model.orderedFields, id: \.key) { field in
                    FieldRow(
                        label: field.label,
                        value: model.value(for: field)?.normalizedValue ?? "",
                        band: model.band(for: field),
                        wasEdited: model.value(for: field)?.wasEditedByUser ?? false
                    ) {
                        beginEditing(field)
                    }
                    .padding(.horizontal, CarbonSpacing.regular)
                }
            }
            .padding(.vertical, CarbonSpacing.regular)
        }
        .carbonBackground()
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .sheet(item: $editingField) { field in
            editor(for: field)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
                Text(model.template.name)
                    .font(CarbonFont.screenTitle)
                    .foregroundStyle(CarbonColor.ink)
                if let capturedAt = model.record?.capturedAt {
                    Text(capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                }
            }
            Spacer()
            if let status = model.record?.status {
                StampBadge(status: status)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: CarbonSpacing.tight) {
            if model.needsReviewCount > 0 {
                Text("\(model.needsReviewCount) need review")
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(CarbonColor.stamp)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.carbonPrimary)
        }
        .padding(CarbonSpacing.regular)
        .background(CarbonColor.paperRaised)
        .overlay(alignment: .top) {
            Rectangle().fill(CarbonColor.rule.opacity(0.5)).frame(height: 1)
        }
    }

    /// Editing opens the right keyboard for the field's declared type. A number field that
    /// opens a QWERTY keyboard is a small thing that makes an app feel unfinished.
    @ViewBuilder
    private func editor(for field: FieldSnapshot) -> some View {
        NavigationStack {
            Form {
                Section {
                    if field.type == .choice, !field.choices.isEmpty {
                        Picker(field.label, selection: $draftValue) {
                            ForEach(field.choices, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.inline)
                    } else {
                        TextField(field.label, text: $draftValue)
                            .font(CarbonFont.dataValue)
                            .keyboardType(keyboardType(for: field.type))
                            .textInputAutocapitalization(
                                field.type == .identifier ? .characters : .sentences
                            )
                            .autocorrectionDisabled(field.type == .identifier)
                    }
                } header: {
                    Text(field.label)
                } footer: {
                    if let raw = model.value(for: field)?.rawText, !raw.isEmpty {
                        // Showing what was read keeps the correction honest: the user can see
                        // whether Carbon misread the page or the page itself is ambiguous.
                        Text("Read from the page as \(raw)")
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingField = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let target = field
                        editingField = nil
                        Task { await model.correct(field: target, to: draftValue) }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func beginEditing(_ field: FieldSnapshot) {
        draftValue = model.value(for: field)?.normalizedValue ?? ""
        editingField = field
    }

    private func keyboardType(for type: FieldType) -> UIKeyboardType {
        switch type {
        case .integer: .numberPad
        case .decimal, .currency: .decimalPad
        case .phone: .phonePad
        default: .default
        }
    }
}
