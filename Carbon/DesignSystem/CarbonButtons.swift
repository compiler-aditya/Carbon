import SwiftUI

/// Filled `carbon`. The verb of whatever screen it is on.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CarbonFont.body.weight(.medium))
            .foregroundStyle(CarbonColor.paperRaised)
            .padding(.vertical, CarbonSpacing.snug)
            .padding(.horizontal, CarbonSpacing.loose)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(CarbonColor.carbon.opacity(isEnabled ? 1 : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: CarbonRadius.chip))
            // No bounce, no shimmer. A tool does not perform at you.
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outlined. Sits beside a primary action without competing with it.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CarbonFont.body)
            .foregroundStyle(CarbonColor.carbon.opacity(isEnabled ? 1 : 0.35))
            .padding(.vertical, CarbonSpacing.snug)
            .padding(.horizontal, CarbonSpacing.loose)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay {
                RoundedRectangle(cornerRadius: CarbonRadius.chip)
                    .stroke(CarbonColor.carbon.opacity(isEnabled ? 1 : 0.35), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var carbonPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var carbonSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Symbol, serif headline, one line of body, one action.
///
/// An empty state is an invitation with something to do, not a mood piece.
struct EmptyState<Actions: View>: View {
    let symbol: String
    let headline: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: CarbonSpacing.regular) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(CarbonColor.inkMuted)

            Text(headline)
                .font(CarbonFont.screenTitle)
                .foregroundStyle(CarbonColor.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(CarbonFont.body)
                .foregroundStyle(CarbonColor.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: CarbonSpacing.snug) { actions }
                .padding(.top, CarbonSpacing.tight)
        }
        .padding(CarbonSpacing.section)
        .carbonReadableWidth()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    EmptyState(
        symbol: "doc.text",
        headline: "No templates yet.",
        message: "A template teaches Carbon the shape of one paper form. "
            + "You'll only do this once per form."
    ) {
        Button("Create your first template") {}.buttonStyle(.carbonPrimary)
        Button("Use a sample form") {}.buttonStyle(.carbonSecondary)
    }
    .carbonBackground()
}
