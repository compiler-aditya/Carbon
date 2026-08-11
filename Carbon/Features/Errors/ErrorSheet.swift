import CarbonCore
import SwiftUI
import UIKit

/// One presentation for every user-facing failure in the app.
///
/// Deliberately a sheet rather than an alert. An alert is a stack of buttons over a screen you
/// can no longer read; this keeps the work behind it visible and gives the sentence room to say
/// what to do. It is also the shape every other interruption in Carbon already takes — paywall,
/// export, editor — so a failure does not arrive looking like a system fault.
///
/// The caller supplies the actions, because only the screen knows what "try again" means on it.
struct ErrorSheet<Actions: View>: View {
    let error: CarbonError
    @ViewBuilder var actions: Actions

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            VStack(spacing: CarbonSpacing.regular) {
                // The message scrolls and the buttons do not. At accessibility sizes this
                // sentence is four lines of serif and the way out has to stay reachable — a
                // sheet whose only action is under the bottom edge is a worse dead end than
                // the one it was written to fix.
                ScrollView {
                    message.padding(.vertical, CarbonSpacing.regular)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: CarbonSpacing.snug) {
                    if error.recovery == .openSettings {
                        Button("Open Settings", action: openSystemSettings)
                            .buttonStyle(.carbonPrimary)
                    }
                    actions
                    Button("Done") { dismiss() }
                        .buttonStyle(.carbonSecondary)
                }
            }
            .padding(CarbonSpacing.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .carbonReadableWidth()
            .carbonBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents(detents)
    }

    private var message: some View {
        VStack(spacing: CarbonSpacing.regular) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(CarbonColor.stamp)

            Text(String(localized: error.title))
                .font(CarbonFont.screenTitle)
                .foregroundStyle(CarbonColor.ink)
                .multilineTextAlignment(.center)
                // Without this the title is compressed to one line and truncated rather than
                // wrapped, which is how "Carbon doesn't have camera access." becomes
                // "Carbon doesn'…".
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: error.guidance))
                .font(CarbonFont.body)
                .foregroundStyle(CarbonColor.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Half a screen is the right size for two sentences and two buttons; at accessibility
    /// sizes it is not, so the sheet starts full-height instead of starting cramped.
    private var detents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large]
    }

    /// The banned-vocabulary rule cuts both ways: a failure gets a plain symbol, not a
    /// catastrophe. Nothing here is broken beyond a page that needs taking again.
    private var symbol: String {
        switch error {
        case .cameraPermissionDenied, .cameraUnavailable: "camera"
        case .imageUnreadable: "photo"
        case .noTableFound, .noFieldsMatched: "doc.text.magnifyingglass"
        case .exportFailed: "square.and.arrow.up"
        default: "exclamationmark.circle"
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        dismiss()
    }
}

extension ErrorSheet where Actions == EmptyView {
    /// For failures whose only honest action is the one already on the screen behind.
    init(error: CarbonError) {
        self.init(error: error) { EmptyView() }
    }
}

#Preview("Wrong template") {
    Color.clear.sheet(isPresented: .constant(true)) {
        ErrorSheet(error: .noFieldsMatched) {
            Button("Scan again") {}.buttonStyle(.carbonPrimary)
        }
    }
}

#Preview("Camera denied") {
    Color.clear.sheet(isPresented: .constant(true)) {
        ErrorSheet(error: .cameraPermissionDenied)
    }
}

#Preview("Photo still in iCloud") {
    Color.clear.sheet(isPresented: .constant(true)) {
        ErrorSheet(error: .imageUnreadable)
    }
}
