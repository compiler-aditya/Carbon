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
    @State private var sourceField: FieldSnapshot?

    /// The two beats of the app's one orchestrated moment. See `runSignature()`.
    @State private var hasLanded = false
    @State private var hasResolved = false

    @Environment(\.services) private var services

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, CarbonSpacing.regular)
                    .padding(.bottom, CarbonSpacing.regular)

                ForEach(Array(model.orderedFields.enumerated()), id: \.element.key) { index, field in
                    FieldRow(
                        label: field.label,
                        value: model.value(for: field)?.normalizedValue ?? "",
                        band: model.band(for: field),
                        wasEdited: model.value(for: field)?.wasEditedByUser ?? false,
                        onTap: { beginEditing(field) },
                        onShowSource: canShowSource(for: field) ? { sourceField = field } : nil,
                        reveal: reveal(row: index)
                    )
                    .padding(.horizontal, CarbonSpacing.regular)
                }
            }
            .padding(.vertical, CarbonSpacing.regular)
            .carbonReadableWidth()
        }
        .carbonBackground()
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load()
            await runSignature()
        }
        .sheet(item: $editingField) { field in
            editor(for: field)
        }
        .sheet(item: $sourceField) { field in
            SourceRegionView(
                model: SourceRegionModel(
                    fieldLabel: field.label,
                    value: model.value(for: field)?.normalizedValue ?? "",
                    pageRef: model.record?.pages.first,
                    frame: model.value(for: field)?.frame,
                    pageStore: services.pageStore
                )
            )
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
        .carbonReadableWidth()
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

    /// The one orchestrated moment in the app, and the reason everything else is quiet.
    ///
    /// Values land in sequence, as if typed onto the form. Then, once the last of them has
    /// settled, the rules resolve from blank to their confidence style. The order is the
    /// argument the whole product makes: **value first, judgement second** — here is what
    /// Carbon read, and only then, here is how sure it is.
    ///
    /// It runs after `load()` so the doubtful-first ordering is already settled. Animating a
    /// list that is about to re-sort itself is how a signature moment becomes a shuffle.
    private func runSignature() async {
        guard !reduceMotion else {
            hasLanded = true
            hasResolved = true
            return
        }

        hasLanded = true

        // Wait for the last value rather than a fixed pause: on a six-field form the stagger
        // is still running when a fixed 200ms would already have fired the rules.
        let lastRow = Double(max(model.orderedFields.count - 1, 0))
        try? await Task.sleep(for: .seconds(lastRow * stagger + landingDuration + settlePause))
        guard !Task.isCancelled else { return }

        hasResolved = true
    }

    private var stagger: Double { 0.04 }
    private var landingDuration: Double { 0.18 }
    private var settlePause: Double { 0.2 }

    /// Both animations are nil under Reduce Motion, which is what makes the flags land without
    /// a transition rather than merely faster.
    private func reveal(row: Int) -> FieldReveal {
        FieldReveal(
            hasLanded: hasLanded,
            resolution: hasResolved ? 1 : 0,
            landing: reduceMotion
                ? nil : .easeOut(duration: landingDuration).delay(Double(row) * stagger),
            resolving: reduceMotion ? nil : .easeInOut(duration: 0.32)
        )
    }

    /// Only offered when there is both a photograph and a region on it. A model-derived value
    /// has no frame — it came from a flat transcript — so pointing at the page would be a lie.
    private func canShowSource(for field: FieldSnapshot) -> Bool {
        model.record?.pages.isEmpty == false && model.value(for: field)?.frame != nil
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
