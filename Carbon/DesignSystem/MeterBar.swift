import CarbonCore
import SwiftUI

/// Free-tier usage. Hairline track, `carbon` fill, count in mono.
///
/// Never red until the limit is actually reached. A meter that turns red at 80% is nagging
/// someone who has done nothing wrong, and it makes the real limit mean less when it arrives.
struct MeterBar: View {
    let label: String
    let used: Int
    let limit: Int

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1, Double(used) / Double(limit))
    }

    private var isAtLimit: Bool { used >= limit }

    var body: some View {
        VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
            HStack {
                Text(label)
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
                Spacer()
                Text("\(used) of \(limit)")
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(isAtLimit ? CarbonColor.stamp : CarbonColor.ink)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(CarbonColor.rule.opacity(0.3))
                        .frame(height: 3)
                    Rectangle()
                        .fill(isAtLimit ? CarbonColor.stamp : CarbonColor.carbon)
                        .frame(width: proxy.size.width * fraction, height: 3)
                }
            }
            .frame(height: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(used) of \(limit) used")
    }
}

#Preview {
    VStack(spacing: CarbonSpacing.loose) {
        MeterBar(label: "Records this month", used: 6, limit: FreeTierLimit.recordsPerPeriod)
        MeterBar(label: "Records this month", used: 20, limit: FreeTierLimit.recordsPerPeriod)
        MeterBar(label: "Templates", used: 1, limit: FreeTierLimit.templates)
    }
    .padding(CarbonSpacing.loose)
    .carbonBackground()
}
