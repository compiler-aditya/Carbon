import CarbonCore
import SwiftUI

/// The table-mode review grid.
///
/// Square cells and hairline rules, because a grid is a grid — this is the one place the
/// design system's rounded corners are explicitly off. A doubtful cell is tinted rather than
/// underlined: the confidence rule does not fit inside a cell, so the grid gets its own
/// version of the same idea.
struct CellGrid: View {
    let template: TemplateSnapshot
    let records: [RecordSnapshot]
    let onEdit: (RecordSnapshot, FieldSnapshot) -> Void

    private let rowNumberWidth: CGFloat = 44
    private let columnWidth: CGFloat = 132
    private let rowHeight: CGFloat = 48

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        row(record, number: index + 1)
                    }
                } header: {
                    headerRow
                }
            }
            // A scroll view centres content shorter than itself. A grid that floats in the
            // middle of the screen reads as a rendering fault, not a design.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(CarbonColor.paperRaised)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            gridCell(width: rowNumberWidth) {
                // The gutter's header is deliberately blank; a row number needs no label.
                Color.clear
            }
            ForEach(template.fields, id: \.key) { field in
                gridCell(width: columnWidth) {
                    Text(field.label)
                        .font(CarbonFont.sectionHeader)
                        .textCase(.uppercase)
                        .foregroundStyle(CarbonColor.inkMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(CarbonColor.paper)
    }

    private func row(_ record: RecordSnapshot, number: Int) -> some View {
        HStack(spacing: 0) {
            gridCell(width: rowNumberWidth) {
                Text("\(number)")
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ForEach(template.fields, id: \.key) { field in
                let value = record.value(forKey: field.key)
                let band = value?.band ?? .needsReview

                Button {
                    onEdit(record, field)
                } label: {
                    gridCell(width: columnWidth, tinted: band == .needsReview) {
                        HStack(spacing: 2) {
                            Text(value?.normalizedValue.isEmpty == false
                                ? value!.normalizedValue : "—")
                                .font(CarbonFont.dataValue)
                                .foregroundStyle(
                                    value?.normalizedValue.isEmpty == false
                                        ? CarbonColor.ink : CarbonColor.inkMuted
                                )
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if value?.wasEditedByUser == true {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(CarbonColor.carbon)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(field.label), row \(number), "
                        + "\(value?.normalizedValue.isEmpty == false ? value!.normalizedValue : "empty"), "
                        + band.spokenDescription
                )
            }
        }
    }

    /// One cell: fixed width, square corners, hairline on two edges so the grid reads as a
    /// single ruled sheet rather than a row of boxes.
    private func gridCell<Content: View>(
        width: CGFloat,
        tinted: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, CarbonSpacing.tight)
            .frame(width: width, height: rowHeight, alignment: .leading)
            .background(tinted ? CarbonColor.stampSoft : .clear)
            .overlay(alignment: .trailing) {
                Rectangle().fill(CarbonColor.rule.opacity(0.5)).frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(CarbonColor.rule.opacity(0.5)).frame(height: 1)
            }
    }
}

#Preview {
    let template = TemplateSnapshot(
        id: UUID(), name: "Daily Register", mode: .table,
        dateConvention: .dayMonthYear, preferredDateFormat: nil,
        fields: [
            FieldSnapshot(
                id: UUID(), key: "date", label: "Date", type: .date, isRequired: false,
                aliases: [], choices: [], defaultValue: nil, currencyCode: nil,
                validationPattern: nil, lastKnownFrame: nil
            ),
            FieldSnapshot(
                id: UUID(), key: "item", label: "Item", type: .text, isRequired: false,
                aliases: [], choices: [], defaultValue: nil, currencyCode: nil,
                validationPattern: nil, lastKnownFrame: nil
            ),
            FieldSnapshot(
                id: UUID(), key: "amount", label: "Amount", type: .currency, isRequired: false,
                aliases: [], choices: [], defaultValue: nil, currencyCode: nil,
                validationPattern: nil, lastKnownFrame: nil
            ),
        ],
        learnedHeaderAliases: []
    )

    let rows = [
        ("01/04/2026", "Basmati rice 5kg", "6720.00", 0.95),
        ("01/04/2026", "Mustard oil 1L", "1484.00", 0.94),
        ("02/04/2026", "Turmeric powder", "", 0.2),
    ]

    return CellGrid(
        template: template,
        records: rows.map { row in
            RecordSnapshot(
                id: UUID(), capturedAt: .now, status: .needsReview, sourceRowIndex: 0,
                values: [
                    ("date", row.0), ("item", row.1), ("amount", row.2),
                ].map { key, value in
                    FieldValueSnapshot(
                        id: UUID(), fieldKey: key, rawText: value, normalizedValue: value,
                        confidence: value.isEmpty ? 0 : row.3,
                        source: value.isEmpty ? .unresolved : .deterministic,
                        wasEditedByUser: false, frame: nil
                    )
                }
            )
        },
        onEdit: { _, _ in }
    )
    .carbonBackground()
}
