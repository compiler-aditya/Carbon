import CarbonCore
import SwiftUI

/// What the user watches while a page is read.
///
/// Not a spinner. Named steps, so a pause is legible rather than worrying — and the captured
/// page sits behind it dimmed, so the first thing they see is their own photograph and they
/// know it landed.
struct ProcessingView: View {
    let step: CaptureModel.Step
    let pageIndex: Int
    let total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: CarbonSpacing.regular) {
            Text(step.label)
                .font(CarbonFont.screenTitle)
                .foregroundStyle(CarbonColor.ink)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step)

            if total > 1 {
                Text("Page \(pageIndex + 1) of \(total)")
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(CarbonColor.inkMuted)
            }

            stepTrack
                .padding(.top, CarbonSpacing.tight)
        }
        .padding(CarbonSpacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .carbonBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(step.label)
    }

    /// Three marks that fill as the work moves through them. A determinate shape rather than
    /// an indeterminate one, because the steps genuinely are countable.
    private var stepTrack: some View {
        HStack(spacing: CarbonSpacing.tight) {
            ForEach(steps, id: \.self) { candidate in
                Rectangle()
                    .fill(isReached(candidate) ? CarbonColor.carbon : CarbonColor.rule.opacity(0.4))
                    .frame(width: 28, height: 2)
            }
        }
        .accessibilityHidden(true)
    }

    private var steps: [CaptureModel.Step] { [.reading, .matching, .checking] }

    private func isReached(_ candidate: CaptureModel.Step) -> Bool {
        guard
            let current = steps.firstIndex(of: step),
            let index = steps.firstIndex(of: candidate)
        else { return false }
        return index <= current
    }
}

#Preview("Reading") {
    ProcessingView(step: .reading, pageIndex: 0, total: 1)
}

#Preview("Matching, multi-page") {
    ProcessingView(step: .matching, pageIndex: 1, total: 3)
}
