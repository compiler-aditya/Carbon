import CarbonCore
import SwiftUI

/// One template in the grid: symbol, name in serif, subtitle, record count in mono, and when
/// it was last used.
struct TemplateCard: View {
    let template: TemplateSnapshot

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CarbonSpacing.tight) {
            Image(systemName: template.symbolName)
                .font(.title2)
                .foregroundStyle(CarbonColor.carbon)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(CarbonFont.cardTitle)
                    .foregroundStyle(CarbonColor.ink)
                    .lineLimit(2)
                if !template.subtitle.isEmpty {
                    Text(template.subtitle)
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: CarbonSpacing.tight)

            // Numbers always in mono, and always with their noun.
            Text("\(template.recordCount) records")
                .font(CarbonFont.dataValue)
                .foregroundStyle(CarbonColor.ink)

            if let lastUsedAt = template.lastUsedAt {
                // .named rather than .numeric: a template used a moment ago should read
                // "now", not "in 0 seconds".
                Text(lastUsedAt.formatted(.relative(presentation: .named)))
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
            }
        }
        .padding(CarbonSpacing.regular)
        // A minimum height keeps a grid of cards even at normal sizes; at accessibility
        // sizes the content is taller than any minimum and must be allowed to set it.
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 150,
            alignment: .leading
        )
        .background(CarbonColor.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: CarbonRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: CarbonRadius.card)
                .stroke(CarbonColor.rule.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The card at the end of the grid. Outlined and dashed, so it reads as a blank form waiting
/// to be filled in rather than as another template.
struct NewTemplateCard: View {
    /// At the free limit the card stays visible and grows a lock. A hidden action teaches
    /// nothing; a gated one teaches what Pro is for.
    let isLocked: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: CarbonSpacing.tight) {
            Image(systemName: isLocked ? "lock" : "plus")
                .font(.title2)
                .foregroundStyle(CarbonColor.carbon)
            Text("New template")
                .font(CarbonFont.body)
                .foregroundStyle(CarbonColor.carbon)
        }
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 110 : 150)
        .overlay {
            RoundedRectangle(cornerRadius: CarbonRadius.card)
                .stroke(
                    CarbonColor.rule,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked ? "New template, needs Carbon Pro" : "New template")
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CarbonSpacing.regular) {
            TemplateCard(
                template: TemplateSnapshot(
                    id: UUID(), name: "Daily Register", mode: .table,
                    dateConvention: .dayMonthYear, preferredDateFormat: nil,
                    fields: [], learnedHeaderAliases: [],
                    subtitle: "Shop sales", symbolName: "tablecells",
                    lastUsedAt: .now.addingTimeInterval(-7200), recordCount: 142
                )
            )
            NewTemplateCard(isLocked: false)
            NewTemplateCard(isLocked: true)
        }
        .padding(CarbonSpacing.regular)
    }
    .carbonBackground()
}
