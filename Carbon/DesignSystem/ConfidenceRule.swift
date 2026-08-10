import CarbonCore
import SwiftUI

/// The line an extracted value sits on, the way ink sits on a printed form line.
///
/// **The line carries information.** Solid means read cleanly, dashed means glance at it,
/// dotted red means it needs you, and a tick means you fixed it. This is structure encoding
/// real content rather than decoration, and it is what makes the human-in-the-loop story
/// legible in a single glance — including in a two-minute video where nobody reads a legend.
///
/// Style is driven by a `ConfidenceBand`, never a bool, so the rule cannot disagree with the
/// number it is describing.
struct ConfidenceRule: View {
    let band: ConfidenceBand
    var wasEdited: Bool = false

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        HStack(spacing: CarbonSpacing.hair) {
            line
            if wasEdited {
                // A small filled tick at the line's end: you fixed this.
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CarbonColor.carbon)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 10)
    }

    private var line: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: thickness)
            .overlay(alignment: .top) {
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 10_000, y: 0))
                }
                .stroke(color, style: strokeStyle)
                .frame(height: thickness)
                .clipped()
            }
    }

    /// Thicker than a hairline divider on purpose. This line is content, not a separator, and
    /// a dotted rule at one physical pixel disappears at 720p in the demo video.
    private var thickness: CGFloat {
        max(1 / displayScale, 0.5) * 1.5
    }

    private var color: Color {
        if wasEdited { return CarbonColor.carbon }
        return switch band {
        case .high: CarbonColor.ink
        case .medium: CarbonColor.carbon
        case .needsReview: CarbonColor.stamp
        }
    }

    private var strokeStyle: StrokeStyle {
        // Dash pattern is the primary channel. Colour is secondary, because confidence must
        // never be conveyed by colour alone.
        if wasEdited { return StrokeStyle(lineWidth: thickness) }
        return switch band {
        case .high: StrokeStyle(lineWidth: thickness)
        case .medium: StrokeStyle(lineWidth: thickness, dash: [4, 3])
        case .needsReview: StrokeStyle(lineWidth: thickness, dash: [1.5, 3], dashPhase: 0)
        }
    }
}

extension ConfidenceBand {
    /// Spoken by VoiceOver. The rule's style is purely visual and carries real information,
    /// so the information has to exist in words too.
    var spokenDescription: String {
        switch self {
        case .high: String(localized: "read cleanly")
        case .medium: String(localized: "worth a glance")
        case .needsReview: String(localized: "needs checking")
        }
    }
}

#Preview("All states") {
    VStack(alignment: .leading, spacing: CarbonSpacing.loose) {
        ForEach(ConfidenceBand.allCases, id: \.self) { band in
            VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
                Text(band.rawValue).font(CarbonFont.fieldLabel).foregroundStyle(CarbonColor.inkMuted)
                Text("1,440.00").font(CarbonFont.dataValue).foregroundStyle(CarbonColor.ink)
                ConfidenceRule(band: band)
            }
        }
        VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
            Text("edited").font(CarbonFont.fieldLabel).foregroundStyle(CarbonColor.inkMuted)
            Text("1,440.00").font(CarbonFont.dataValue).foregroundStyle(CarbonColor.ink)
            ConfidenceRule(band: .high, wasEdited: true)
        }
    }
    .padding(CarbonSpacing.loose)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .carbonBackground()
}
