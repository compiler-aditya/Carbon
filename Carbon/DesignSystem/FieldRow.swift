import CarbonCore
import SwiftUI

/// Label above, value on a confidence rule. The most important component in the app.
///
/// VoiceOver reads the whole row as one thing — "Quantity, 1440, needs checking" — because
/// the rule's meaning is otherwise purely visual, and a screen reader user has to get the
/// same information the rule gives everyone else.
struct FieldRow: View {
    let label: String
    let value: String
    let band: ConfidenceBand
    var wasEdited: Bool = false
    var onTap: (() -> Void)?

    /// Shown only when there is a photograph and a known region to show. Tapping it answers
    /// "where did this come from?" — which is the question a doubtful value provokes.
    var onShowSource: (() -> Void)?

    /// The row's part in the Review animation. Defaults to settled, so every other call site
    /// and preview renders finished.
    var reveal: FieldReveal = .settled

    var body: some View {
        VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
            Text(label)
                .font(CarbonFont.fieldLabel)
                .textCase(.uppercase)
                .foregroundStyle(CarbonColor.inkMuted)

            HStack(spacing: CarbonSpacing.tight) {
                Text(displayValue)
                    .font(CarbonFont.dataValue)
                    .foregroundStyle(value.isEmpty ? CarbonColor.inkMuted : CarbonColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Only the value moves. The label and the rule are the printed form; the
                    // value is what was written onto it, so it is the only thing that arrives.
                    .opacity(reveal.hasLanded ? 1 : 0)
                    .offset(y: reveal.hasLanded ? 0 : 6)
                    // Scoped to this Text on purpose. Hung on the row instead, the same
                    // transaction animates the row's *height* when a two-line value arrives,
                    // and the rows below slide up through the one above.
                    .animation(reveal.landing, value: reveal.hasLanded)

                if let onShowSource {
                    Button(action: onShowSource) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(CarbonColor.carbon)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Show \(label) on the page")
                }
            }

            ConfidenceRule(band: band, wasEdited: wasEdited, resolution: reveal.resolution)
                .animation(reveal.resolving, value: reveal.resolution)
        }
        .padding(.vertical, CarbonSpacing.tight)
        .contentShape(.rect)
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    /// An unresolved field shows an em dash rather than nothing, so the row still has a value
    /// slot and the layout does not jump when one gets filled in.
    private var displayValue: String {
        value.isEmpty ? "—" : value
    }

    private var accessibilityText: String {
        let spoken = value.isEmpty ? String(localized: "empty") : value
        let state = wasEdited ? String(localized: "you corrected this") : band.spokenDescription
        return "\(label), \(spoken), \(state)"
    }
}

/// A row's share of the Review animation, carried as one value so the two beats cannot be set
/// half-and-half at a call site.
///
/// The animations travel with the flags rather than being applied by the caller, because where
/// they are attached is load-bearing: each has to be scoped to the thing it animates, or the
/// same transaction picks up the row's layout as well.
struct FieldReveal {
    var hasLanded = true
    var resolution: Double = 1
    var landing: Animation?
    var resolving: Animation?

    /// Fully arrived, with nothing to animate. What every screen other than Review wants.
    static let settled = FieldReveal()
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        FieldRow(label: "Date", value: "01/04/2026", band: .high)
        FieldRow(label: "Item", value: "Basmati rice 5kg", band: .high)
        FieldRow(label: "Quantity", value: "12", band: .medium)
        FieldRow(label: "Rate", value: "560.00", band: .needsReview)
        FieldRow(label: "Amount", value: "", band: .needsReview)
        FieldRow(label: "Branch", value: "Main", band: .high, wasEdited: true)
    }
    .padding(CarbonSpacing.regular)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .carbonBackground()
}
