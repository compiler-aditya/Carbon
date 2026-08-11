import CarbonCore
import CoreGraphics
import SwiftUI

/// Shows where on the photographed page a value was read from.
///
/// Small feature, disproportionate effect: it is the difference between an app that says it
/// read your page and one you can watch having read it. It is also the honest answer when a
/// value looks wrong — often the page really is ambiguous, and seeing that is more useful than
/// arguing with the number.
@MainActor
@Observable
final class SourceRegionModel {
    enum State {
        case loading
        case region(CGImage, highlight: NormalizedRect)
        case wholePage(CGImage, highlight: NormalizedRect)
        case unavailable
    }

    private(set) var state: State = .loading

    let fieldLabel: String
    let value: String
    private let pageRef: PageRef?
    private let frame: NormalizedRect?
    private let pageStore: any PageStoring

    init(
        fieldLabel: String,
        value: String,
        pageRef: PageRef?,
        frame: NormalizedRect?,
        pageStore: any PageStoring
    ) {
        self.fieldLabel = fieldLabel
        self.value = value
        self.pageRef = pageRef
        self.frame = frame
        self.pageStore = pageStore
    }

    var canToggle: Bool {
        if case .unavailable = state { false } else { frame != nil }
    }

    var isShowingWholePage: Bool {
        if case .wholePage = state { true } else { false }
    }

    func load() async {
        guard let pageRef, let image = try? await pageStore.load(pageRef) else {
            // The photograph may have been purged from Settings, or never written. The value
            // is still perfectly valid — only its provenance is gone.
            state = .unavailable
            return
        }

        guard let frame else {
            state = .wholePage(image, highlight: NormalizedRect(x: 0, y: 0, width: 1, height: 1))
            return
        }
        state = crop(image, to: frame)
    }

    func toggleWholePage() {
        switch state {
        case .region(let image, _):
            guard let frame else { return }
            state = .wholePage(image, highlight: frame)
        case .wholePage(let image, _):
            guard let frame else { return }
            state = crop(image, to: frame)
        default:
            break
        }
    }

    private func crop(_ image: CGImage, to frame: NormalizedRect) -> State {
        let rect = SourceRegionCrop.pixelRect(
            for: frame, imageWidth: image.width, imageHeight: image.height
        )
        guard let cropped = image.cropping(to: rect) else {
            return .wholePage(image, highlight: frame)
        }
        return .region(
            cropped,
            highlight: SourceRegionCrop.highlight(
                for: frame, within: rect, imageWidth: image.width, imageHeight: image.height
            )
        )
    }
}

struct SourceRegionView: View {
    @State var model: SourceRegionModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: CarbonSpacing.regular) {
                content
                caption
            }
            .padding(CarbonSpacing.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .carbonBackground()
            .navigationTitle("On the page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if model.canToggle {
                    ToolbarItem(placement: .primaryAction) {
                        Button(model.isShowingWholePage ? "Zoom in" : "Whole page") {
                            model.toggleWholePage()
                        }
                    }
                }
            }
            .task { await model.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView().frame(maxHeight: .infinity)

        case .region(let image, let highlight), .wholePage(let image, let highlight):
            GeometryReader { proxy in
                let size = fittedSize(for: image, in: proxy.size)
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        // Drawn over the image rather than beside it, so there is no doubt
                        // which marks on the page produced the value.
                        Rectangle()
                            .stroke(CarbonColor.stamp, lineWidth: 2)
                            .frame(
                                width: highlight.width * size.width,
                                height: highlight.height * size.height
                            )
                            .position(
                                x: (highlight.x + highlight.width / 2) * size.width,
                                y: (highlight.y + highlight.height / 2) * size.height
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityLabel(
                "The page, with \(model.fieldLabel) outlined where Carbon read it."
            )

        case .unavailable:
            EmptyState(
                symbol: "photo",
                headline: String(localized: "The photo is gone."),
                message: String(
                    localized: """
                        Its images were deleted to save space. The record itself is unchanged.
                        """
                )
            ) {
                EmptyView()
            }
        }
    }

    private var caption: some View {
        VStack(spacing: CarbonSpacing.hair) {
            Text(model.fieldLabel)
                .font(CarbonFont.fieldLabel)
                .textCase(.uppercase)
                .foregroundStyle(CarbonColor.inkMuted)
            Text(model.value.isEmpty ? "—" : model.value)
                .font(CarbonFont.dataValueLarge)
                .foregroundStyle(CarbonColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// Fits the image inside the available space without distorting it — an aspect-filled
    /// crop would move the highlight off the value it is pointing at.
    private func fittedSize(for image: CGImage, in available: CGSize) -> CGSize {
        let imageAspect = Double(image.width) / Double(image.height)
        let availableAspect = available.width / max(available.height, 1)

        return imageAspect > availableAspect
            ? CGSize(width: available.width, height: available.width / imageAspect)
            : CGSize(width: available.height * imageAspect, height: available.height)
    }
}
