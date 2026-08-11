import CoreGraphics
import Foundation
import Testing

@testable import CarbonCore

@Suite("Source region crop")
struct SourceRegionCropTests {
    private let width = 1000
    private let height = 800

    @Test("A crop includes context around the value, not just the value")
    func includesMargin() {
        let frame = NormalizedRect(x: 0.4, y: 0.4, width: 0.2, height: 0.1)
        let crop = SourceRegionCrop.pixelRect(
            for: frame, imageWidth: width, imageHeight: height
        )

        // The value alone is 200×80. Cropped to exactly that, you cannot tell which column or
        // row you are looking at.
        #expect(crop.width > 200)
        #expect(crop.height > 80)
        #expect(crop.contains(CGRect(x: 400, y: 320, width: 200, height: 80)))
    }

    @Test("A crop never leaves the page")
    func clampsToPage() {
        for frame in [
            NormalizedRect(x: 0, y: 0, width: 0.2, height: 0.05),
            NormalizedRect(x: 0.85, y: 0.95, width: 0.15, height: 0.05),
        ] {
            let crop = SourceRegionCrop.pixelRect(
                for: frame, imageWidth: width, imageHeight: height
            )
            #expect(crop.minX >= 0)
            #expect(crop.minY >= 0)
            #expect(crop.maxX <= Double(width))
            #expect(crop.maxY <= Double(height))
        }
    }

    @Test("A single line of text still gets a readable crop, not a letterbox slit")
    func shortRegionsGetVerticalRoom() {
        // 1% of the page tall — one line in a dense register.
        let line = NormalizedRect(x: 0.3, y: 0.5, width: 0.3, height: 0.01)
        let crop = SourceRegionCrop.pixelRect(
            for: line, imageWidth: width, imageHeight: height
        )
        // The line itself is 8px tall. Proportional padding alone would add about 5px, which
        // is still a slit; the floor is what makes the neighbouring rows visible.
        let lineHeightInPixels = line.height * Double(height)
        #expect(crop.height >= lineHeightInPixels * 4)
    }

    @Test("The highlight lands on the value within the crop")
    func highlightIsPositionedWithinTheCrop() {
        let frame = NormalizedRect(x: 0.4, y: 0.4, width: 0.2, height: 0.1)
        let crop = SourceRegionCrop.pixelRect(
            for: frame, imageWidth: width, imageHeight: height
        )
        let highlight = SourceRegionCrop.highlight(
            for: frame, within: crop, imageWidth: width, imageHeight: height
        )

        #expect(highlight.x > 0 && highlight.x < 1)
        #expect(highlight.y > 0 && highlight.y < 1)
        #expect(highlight.width > 0 && highlight.width <= 1)

        // The value is centred in its own crop, so the highlight should be too.
        #expect(abs((highlight.x + highlight.width / 2) - 0.5) < 0.05)
        #expect(abs((highlight.y + highlight.height / 2) - 0.5) < 0.05)
    }

    @Test("A value at the page edge highlights correctly even though the crop was clamped")
    func highlightSurvivesClamping() {
        let corner = NormalizedRect(x: 0, y: 0, width: 0.2, height: 0.05)
        let crop = SourceRegionCrop.pixelRect(
            for: corner, imageWidth: width, imageHeight: height
        )
        let highlight = SourceRegionCrop.highlight(
            for: corner, within: crop, imageWidth: width, imageHeight: height
        )
        // Clamping pushed the crop against the corner, so the value sits at its edge — not
        // off it, and not re-centred as if the page continued.
        #expect(abs(highlight.x) < 0.0001)
        #expect(abs(highlight.y) < 0.0001)
    }

    @Test("A zero-size crop cannot divide by zero")
    func degenerateCrop() {
        let frame = NormalizedRect(x: 0.2, y: 0.2, width: 0.1, height: 0.1)
        let highlight = SourceRegionCrop.highlight(
            for: frame, within: .zero, imageWidth: width, imageHeight: height
        )
        #expect(highlight == frame)
    }
}
