import CarbonCore
import CarbonTestFixtures
import RevenueCat
import RevenueCatUI
import SwiftUI

/// Settings. Carries the Pro status and the restore path, plus the privacy statement — which
/// is a real claim about how the app works, so it is stated plainly rather than as a link.
struct SettingsView: View {
    @Environment(\.services) private var services

    @State private var isShowingPaywall = false
    @State private var restoreOutcome: RestoreOutcome?
    @State private var modelState: ModelAvailability.State?

    var body: some View {
        List {
            proSection
            extractionSection
            privacySection
            aboutSection
        }
        .task {
            modelState = await ModelAvailability().state()
        }
        .sheet(isPresented: $isShowingPaywall) {
            // Presented from the action, never from the app root. The user sees the paywall
            // because they asked for something, which is what keeps its context obvious.
            PaywallView(displayCloseButton: true)
        }
        .alert(item: $restoreOutcome) { outcome in
            Alert(title: Text(outcome.message), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section("Carbon Pro") {
            LabeledContent("Status", value: statusLabel)

            if !services.entitlements.isPro {
                Button("See Carbon Pro") { isShowingPaywall = true }
                    .disabled(!Purchases.isConfigured)
            }

            Button("Restore purchases") {
                Task { await restore() }
            }
            .disabled(!Purchases.isConfigured)

            if !Purchases.isConfigured {
                Text(
                    "Purchases aren't set up in this build. Everything else works — "
                        + "see the README to add a key."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// One line, never an alert, and never blocking anything.
    ///
    /// Extraction has already run and produced a usable result by the time anyone reads this.
    /// It exists so someone who wonders why a form took more correcting than usual can find
    /// out — not to ask them to fix something.
    @ViewBuilder
    private var extractionSection: some View {
        Section("Extraction") {
            switch modelState {
            case .available:
                Text("Carbon is using on-device intelligence for fields it can't place by layout.")
                    .font(CarbonFont.callout)
            case .unavailable(let reason):
                VStack(alignment: .leading, spacing: CarbonSpacing.hair) {
                    Text(String(localized: reason.settingsTitle))
                        .font(CarbonFont.body)
                    Text(String(localized: reason.settingsGuidance))
                        .font(CarbonFont.caption)
                        .foregroundStyle(CarbonColor.inkMuted)
                }
            case nil:
                Text("Checking…")
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.inkMuted)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Text(
                "Photographs and extracted values never leave this device. "
                    + "The only outbound traffic is RevenueCat's own SDK."
            )
            .font(.callout)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: AppConfig.version)
        }
    }

    private var statusLabel: String {
        switch services.entitlements.status {
        case .pro: "Pro"
        case .free: "Free"
        case .unknown: "Not configured"
        }
    }

    private func restore() async {
        do {
            try await services.entitlements.restore()
            restoreOutcome =
                services.entitlements.isPro
                ? .init(message: "Carbon Pro restored.")
                // Not an error state. Nothing went wrong; there was simply nothing to find.
                : .init(message: "No previous purchase found on this Apple ID.")
        } catch {
            restoreOutcome = .init(message: "Couldn't reach the store. Try again in a moment.")
        }
    }
}

private struct RestoreOutcome: Identifiable {
    let id = UUID()
    let message: String
}

#Preview("Free") {
    NavigationStack { SettingsView().navigationTitle("Settings") }
        .environment(\.services, .preview())
}

#Preview("Pro") {
    NavigationStack { SettingsView().navigationTitle("Settings") }
        .environment(\.services, .previewPro())
}

#Preview("No key configured") {
    NavigationStack { SettingsView().navigationTitle("Settings") }
        .environment(\.services, .previewUnconfigured())
}
