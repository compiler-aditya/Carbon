import CoreGraphics
import Vision

/// The one place Vision's geometry is converted into ours.
///
/// `NormalizedRegion` is a contour, not a rectangle — it can describe a quadrilateral, which
/// is how a page photographed at an angle is represented honestly. We flatten it to its
/// bounding rectangle because every consumer (zoom-to-field, column matching, row ordering)
/// wants a rectangle, and we flip the origin here because Vision measures from the bottom
/// left and SwiftUI from the top left.
///
/// Doing the flip in exactly one place is deliberate: a coordinate conversion that happens in
/// two places eventually happens in only one of them, and the symptom is a zoom target
/// mirrored vertically that nobody can reproduce.
enum VisionGeometry {
    static func rect(from region: NormalizedRegion) -> CarbonCore.NormalizedRect {
        flip(region.normalizedPath.boundingBox)
    }

    /// Converts a bottom-left-origin normalized rect to top-left origin.
    static func flip(_ box: CGRect) -> CarbonCore.NormalizedRect {
        CarbonCore.NormalizedRect(
            x: box.origin.x,
            y: 1.0 - box.origin.y - box.height,
            width: box.width,
            height: box.height
        )
    }
}
