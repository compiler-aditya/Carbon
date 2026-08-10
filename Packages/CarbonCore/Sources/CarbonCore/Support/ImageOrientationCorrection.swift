import CoreGraphics
import CoreImage
import ImageIO

/// Rotates an image so it is upright, discarding the EXIF orientation flag.
///
/// A photo from the library carries its rotation as metadata, and a `CGImage` does not carry
/// metadata. Vision would accept the orientation as a separate argument, but that only fixes
/// recognition — the JPEG we persist would still be sideways, and every stored frame would
/// point at the wrong part of it. Baking the rotation in once, at import, keeps a single
/// upright image flowing through recognition, storage and zoom-to-field alike.
///
/// Photos from the document camera are already upright, so this is only on the import path.
public enum ImageOrientationCorrection {
    /// Shared because building a `CIContext` per image is expensive and this runs once per
    /// imported page.
    private static let renderContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Returns an upright copy, or the original when it is already upright or cannot be
    /// rendered. Failing back to the original is deliberate: a sideways scan the user can
    /// retake beats an import that silently produces nothing.
    public static func upright(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> CGImage {
        guard orientation != .up else { return image }

        let oriented = CIImage(cgImage: image).oriented(orientation)
        return renderContext.createCGImage(oriented, from: oriented.extent) ?? image
    }

    /// Reads the orientation an image file declares, defaulting to upright when it says
    /// nothing — which is what a screenshot or a rendered page does.
    public static func orientation(ofImageAt source: CGImageSource) -> CGImagePropertyOrientation {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let raw = properties[kCGImagePropertyOrientation] as? UInt32,
            let orientation = CGImagePropertyOrientation(rawValue: raw)
        else { return .up }
        return orientation
    }

    /// Decodes image data into an upright `CGImage`.
    ///
    /// The single entry point for "a photo arrived from somewhere that is not the camera" —
    /// the library today, a share sheet later. Deliberately a function rather than something
    /// living in view code, so a second entry point costs one call.
    public static func decodeUpright(_ data: Data) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        return upright(image, orientation: orientation(ofImageAt: source))
    }
}
