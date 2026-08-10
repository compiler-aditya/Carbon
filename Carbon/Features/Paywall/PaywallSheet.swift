import CarbonCore
import RevenueCat
import RevenueCatUI
import SwiftUI

/// Presents the dashboard-configured paywall, with an honest fallback when no key is set.
///
/// A fresh clone has no RevenueCat key, and `PaywallView` with nothing behind it would be a
/// confusing dead end. Saying so plainly is better than showing an empty paywall.
struct PaywallSheet: View {
    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if Purchases.isConfigured {
            PaywallView(displayCloseButton: true)
        } else {
            unconfigured
        }
    }

    private var unconfigured: some View {
        EmptyState(
            symbol: "lock",
            headline: String(localized: "Carbon Pro"),
            message: contextLine + " "
                + String(
                    localized: "Purchases aren't set up in this build — see the README to add a key."
                )
        ) {
            Button("Close") { dismiss() }
                .buttonStyle(.carbonSecondary)
        }
        .carbonBackground()
    }

    /// Why they are seeing this. A paywall that explains the action it interrupted is a very
    /// different experience from one that appears for no stated reason.
    private var contextLine: String {
        switch reason {
        case .templateLimit:
            String(localized: "Free covers one template.")
        case .recordLimit:
            String(localized: "Free covers 20 records a month.")
        case .export:
            String(localized: "Export is part of Carbon Pro.")
        }
    }
}

#Preview {
    PaywallSheet(reason: .recordLimit)
}
