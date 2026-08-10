import CarbonCore
import SwiftUI

/// Status in the rubber-stamp idiom: outlined, slightly rotated, uppercase, letterspaced.
///
/// This is where the interface is allowed a little personality — everything around it stays
/// quiet. It also carries the status **as a word**, which is what keeps confidence from being
/// conveyed by colour alone.
struct StampBadge: View {
    let status: RecordStatus

    var body: some View {
        Text(title)
            .font(CarbonFont.stamp)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(tint)
            .padding(.horizontal, CarbonSpacing.tight)
            .padding(.vertical, CarbonSpacing.hair)
            .overlay {
                RoundedRectangle(cornerRadius: CarbonRadius.chip)
                    .stroke(tint, lineWidth: 1.5)
            }
            .rotationEffect(.degrees(-2))
            .accessibilityLabel(title)
    }

    private var title: String {
        switch status {
        case .draft: String(localized: "Draft")
        case .needsReview: String(localized: "Needs review")
        case .confirmed: String(localized: "Confirmed")
        }
    }

    private var tint: Color {
        switch status {
        case .draft: CarbonColor.inkMuted
        case .needsReview: CarbonColor.stamp
        case .confirmed: CarbonColor.confirm
        }
    }
}

/// Uppercase heading with a hairline running to the trailing edge.
struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: CarbonSpacing.tight) {
            Text(title)
                .font(CarbonFont.sectionHeader)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(CarbonColor.inkMuted)
            Rectangle()
                .fill(CarbonColor.rule.opacity(0.5))
                .frame(height: 1)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CarbonSpacing.loose) {
        HStack(spacing: CarbonSpacing.snug) {
            StampBadge(status: .needsReview)
            StampBadge(status: .confirmed)
            StampBadge(status: .draft)
        }
        SectionHeader("Fields")
    }
    .padding(CarbonSpacing.loose)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .carbonBackground()
}
