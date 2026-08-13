import CarbonCore
import RevenueCat
import RevenueCatUI
import SwiftUI

#if DEBUG
    import CarbonTestFixtures
#endif

/// Settings. Carries the Pro status and the restore path, plus the privacy statement — which
/// is a real claim about how the app works, so it is stated plainly rather than as a link.
struct SettingsView: View {
    @Environment(\.services) private var services

    @State private var isShowingPaywall = false
    @State private var restoreOutcome: RestoreOutcome?
    @State private var modelState: ModelAvailability.State?
    @State private var usage: UsagePeriodSnapshot?
    @State private var templateCount = 0
    @State private var storageBytes = 0
    @State private var purgeableRecords = 0
    @State private var exportSummary: ExportSummary = .empty
    @State private var purgeFailure: CarbonError?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            usageSection
            proSection
            storageSection
            extractionSection
            privacySection
            aboutSection
        }
        // Grouped, because sections of settings are what a grouped list is for and this screen
        // should feel like the system's. Only the colour changes: the app's paper underneath
        // and raised paper for the rows, instead of iOS grey and pure white. Settings was the
        // one screen still wearing the default palette while its own contents used the tokens.
        .listRowBackground(CarbonColor.paperRaised)
        .scrollContentBackground(.hidden)
        .carbonBackground()
        .task {
            modelState = await ModelAvailability().state()
            await loadUsage()
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

    /// What the free tier has left. Shown to everyone: a Pro user sees what they are getting,
    /// and a free user sees where they stand before they hit a wall rather than at it.
    @ViewBuilder
    private var usageSection: some View {
        if !services.entitlements.isPro {
            Section("Usage") {
                MeterBar(
                    label: String(localized: "Templates"),
                    used: templateCount,
                    limit: FreeTierLimit.templates
                )
                MeterBar(
                    label: String(localized: "Records this month"),
                    used: usage?.recordsCreated ?? 0,
                    limit: FreeTierLimit.recordsPerPeriod
                )
            }
        }
    }

    /// Storage. Shows the number and offers the choice — v1 never auto-purges someone's
    /// source images.
    private var storageSection: some View {
        Section("Storage") {
            LabeledContent("Scans on this device", value: formattedBytes)

            if exportSummary.exportCount > 0 {
                LabeledContent(
                    "Exported",
                    value: "\(exportSummary.exportCount) files, \(exportSummary.recordCount) records"
                )
            }

            Button("Delete images for \(purgeableRecords) confirmed records") {
                Task { await purgeImages() }
            }
            .disabled(purgeableRecords == 0)

            Text(
                "Records you've already checked keep their data. "
                    + "Anything still needing review keeps its photo."
            )
            .font(CarbonFont.caption)
            .foregroundStyle(CarbonColor.inkMuted)

            // A purge that failed used to leave the same number on screen and say nothing,
            // which reads as the button not working rather than as the deletion not happening.
            if let purgeFailure {
                Text(String(localized: purgeFailure.title))
                    .font(CarbonFont.caption)
                    .foregroundStyle(CarbonColor.stamp)
            }
        }
    }

    private var formattedBytes: String {
        storageBytes.formatted(.byteCount(style: .file))
    }

    private var store: CarbonStore {
        CarbonStore(modelContainer: modelContext.container)
    }

    private func loadUsage() async {
        usage = await services.meter.currentPeriod()
        templateCount = (try? await store.templateCount()) ?? 0
        storageBytes = (try? await services.pageStore.totalBytes()) ?? 0
        purgeableRecords = (try? await store.confirmedRecordsWithImages()) ?? 0
        exportSummary = (try? await store.exportSummary()) ?? .empty
    }

    private func purgeImages() async {
        do {
            purgeFailure = nil
            try await store.purgeImagesForConfirmedRecords(pageStore: services.pageStore)
        } catch {
            purgeFailure = .saveFailed(underlying: String(describing: error))
        }
        await loadUsage()
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

#if DEBUG

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

#endif
