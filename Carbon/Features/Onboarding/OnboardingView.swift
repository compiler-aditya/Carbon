import CarbonCore
import SwiftUI

/// Three screens, skippable, one sentence each.
///
/// No permission prompt anywhere in here — camera access is asked for at first actual use,
/// when the request explains itself. Asking on screen one is how an app gets refused by
/// someone who has not yet seen a reason to say yes.
struct OnboardingView: View {
    let onCreateOwn: () -> Void
    let onUseSample: (SampleFormLibrary.Sample) -> Void
    let onSkip: () -> Void

    @State private var page = 0

    private struct Beat {
        let headline: String
        let body: String
        let symbol: String
    }

    private let beats: [Beat] = [
        Beat(
            headline: String(localized: "Paper you can't get rid of."),
            body: String(
                localized: """
                    Some registers have to stay on paper. The spreadsheet still has to exist, \
                    so someone types it twice.
                    """
            ),
            symbol: "doc.on.doc"
        ),
        Beat(
            headline: String(localized: "Map the form once."),
            body: String(
                localized: """
                    Show Carbon the form and name its fields. You'll only do this once per form.
                    """
            ),
            symbol: "square.grid.3x3.topleft.filled"
        ),
        Beat(
            headline: String(localized: "Then every photo is a row."),
            body: String(
                localized: """
                    Photograph the filled page and the values land in the same shaped dataset, \
                    every time.
                    """
            ),
            symbol: "camera"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(beats.indices, id: \.self) { index in
                    beatView(beats[index]).tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            actions
                .padding(CarbonSpacing.regular)
                .carbonReadableWidth()
        }
        .carbonBackground()
        .overlay(alignment: .topTrailing) {
            if page < beats.count - 1 {
                Button("Skip", action: onSkip)
                    .font(CarbonFont.body)
                    .foregroundStyle(CarbonColor.inkMuted)
                    .padding(CarbonSpacing.regular)
            }
        }
    }

    private func beatView(_ beat: Beat) -> some View {
        VStack(spacing: CarbonSpacing.loose) {
            Spacer()
            Image(systemName: beat.symbol)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(CarbonColor.carbon)

            VStack(spacing: CarbonSpacing.snug) {
                Text(beat.headline)
                    .font(CarbonFont.title)
                    .foregroundStyle(CarbonColor.ink)
                    .multilineTextAlignment(.center)

                Text(beat.body)
                    .font(CarbonFont.body)
                    .foregroundStyle(CarbonColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, CarbonSpacing.section)
        .carbonReadableWidth()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        if page < beats.count - 1 {
            Button("Next") {
                withAnimation { page += 1 }
            }
            .buttonStyle(.carbonPrimary)
        } else {
            VStack(spacing: CarbonSpacing.snug) {
                // The sample path leads, because it is the one that shows the whole product
                // working in a single tap — and on a simulator it is the only one that can.
                if SampleFormLibrary.isAvailable {
                    Menu {
                        ForEach(SampleFormLibrary.all) { sample in
                            Button(sample.name) { onUseSample(sample) }
                        }
                    } label: {
                        Text("Start with a sample form")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.carbonPrimary)
                }

                Button("Create my own", action: onCreateOwn)
                    .buttonStyle(
                        SampleFormLibrary.isAvailable ? AnyButtonStyle(.carbonSecondary)
                            : AnyButtonStyle(.carbonPrimary)
                    )
            }
        }
    }
}

/// Lets one call site choose between two button styles without duplicating the view.
private struct AnyButtonStyle: ButtonStyle {
    private let makeBody: (Configuration) -> AnyView

    init<Style: ButtonStyle>(_ style: Style) {
        makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBody(configuration)
    }
}

#Preview {
    OnboardingView(onCreateOwn: {}, onUseSample: { _ in }, onSkip: {})
}
