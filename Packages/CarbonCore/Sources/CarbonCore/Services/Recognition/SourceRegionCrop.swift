import CoreGraphics
import Foundation

/// Works out which part of a scanned page a value came from.
///
/// This is what makes "tap a value, see where it came from" possible, and that feature does
/// more work than its size suggests: it is the difference between an app that claims to read
/// your page and one that visibly did.
public enum SourceRegionCrop {
    /// How much of the surrounding page to include, as a fraction of the region's own size.
    ///
    /// A cell cropped exactly to its own bounds is unreadable as *context* — you cannot tell
    /// which column or which row you are looking at. A little of the neighbours makes the
    /// answer obvious.
    public static let defaultMargin = 0.6

    /// Converts a normalised, top-left-origin rect into pixel coordinates for `CGImage`,
    /// expanded by a margin and clamped to the page.
    ///
    /// `CGImage.cropping(to:)` also measures from the top left, so no flip is needed here —
    /// the flip already happened once, at the Vision boundary.
    public static func pixelRect(
        for frame: NormalizedRect,
        imageWidth: Int,
        imageHeight: Int,
        margin: Double = defaultMargin
    ) -> CGRect {
        let width = Double(imageWidth)
        let height = Double(imageHeight)

        let padX = frame.width * width * margin
        let padY = frame.height * height * margin

        // A very short region — a single line of text — gets a floor on vertical padding, or
        // the crop is a letterbox slit with no way to tell one row from another.
        let minimumPadY = height * 0.02

        let rawX = frame.x * width - padX
        let rawY = frame.y * height - max(padY, minimumPadY)
        let rawWidth = frame.width * width + padX * 2
        let rawHeight = frame.height * height + max(padY, minimumPadY) * 2

        let x = max(0, rawX)
        let y = max(0, rawY)
        return CGRect(
            x: x,
            y: y,
            width: min(rawWidth, width - x),
            height: min(rawHeight, height - y)
        )
    }

    /// Where the value sits *inside* the cropped image, normalised — so the highlight can be
    /// drawn over the crop without recomputing anything.
    public static func highlight(
        for frame: NormalizedRect,
        within crop: CGRect,
        imageWidth: Int,
        imageHeight: Int
    ) -> NormalizedRect {
        guard crop.width > 0, crop.height > 0 else { return frame }

        let width = Double(imageWidth)
        let height = Double(imageHeight)

        return NormalizedRect(
            x: (frame.x * width - crop.origin.x) / crop.width,
            y: (frame.y * height - crop.origin.y) / crop.height,
            width: frame.width * width / crop.width,
            height: frame.height * height / crop.height
        )
    }
}
