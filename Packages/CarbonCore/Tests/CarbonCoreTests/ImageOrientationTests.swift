import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import CarbonCore

@Suite("Image orientation")
struct ImageOrientationTests {
    /// A wide image with a single black square in one known corner, so a rotation is
    /// detectable rather than merely plausible.
    private func makeMarkedImage(width: Int = 80, height: Int = 40) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 0, alpha: 1)
        // CoreGraphics origin is bottom-left, so this is the image's TOP-left corner.
        context.fill(CGRect(x: 0, y: height - 10, width: 10, height: 10))
        return context.makeImage()!
    }

    /// Average brightness of a 10×10 corner, reading top-left in image terms.
    private func topLeftIsDark(_ image: CGImage) -> Bool {
        let width = image.width
        var pixels = [UInt8](repeating: 0, count: width * image.height * 4)
        let context = CGContext(
            data: &pixels, width: width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: image.height))

        // Row 0 of the buffer is the top row of the image.
        var total = 0
        for y in 0..<5 {
            for x in 0..<5 {
                total += Int(pixels[(y * width + x) * 4])
            }
        }
        return total / 25 < 128
    }

    @Test("An upright image is returned untouched")
    func upIsUnchanged() {
        let image = makeMarkedImage()
        let result = ImageOrientationCorrection.upright(image, orientation: .up)
        #expect(result.width == image.width)
        #expect(result.height == image.height)
        #expect(topLeftIsDark(result))
    }

    @Test(
        "Quarter turns swap the dimensions",
        arguments: [
            CGImagePropertyOrientation.left,
            .right,
            .leftMirrored,
            .rightMirrored,
        ]
    )
    func quarterTurnsSwapDimensions(orientation: CGImagePropertyOrientation) {
        let image = makeMarkedImage(width: 80, height: 40)
        let result = ImageOrientationCorrection.upright(image, orientation: orientation)
        #expect(result.width == 40)
        #expect(result.height == 80)
    }

    @Test(
        "Half turns keep the dimensions",
        arguments: [CGImagePropertyOrientation.down, .upMirrored, .downMirrored]
    )
    func halfTurnsKeepDimensions(orientation: CGImagePropertyOrientation) {
        let image = makeMarkedImage(width: 80, height: 40)
        let result = ImageOrientationCorrection.upright(image, orientation: orientation)
        #expect(result.width == 80)
        #expect(result.height == 40)
    }

    @Test("Rotating 180 moves the mark off the top-left corner")
    func downMovesTheMark() {
        let result = ImageOrientationCorrection.upright(makeMarkedImage(), orientation: .down)
        #expect(!topLeftIsDark(result), "the mark should no longer be top-left after a half turn")
    }

    @Test("A file declaring no orientation is treated as upright")
    func missingOrientationDefaultsToUp() throws {
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, makeMarkedImage(), nil)
        #expect(CGImageDestinationFinalize(destination))

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(ImageOrientationCorrection.orientation(ofImageAt: source) == .up)
    }

    @Test("Decoding produces an upright image from raw file data")
    func decodeUpright() throws {
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        )
        // Declare a quarter turn in the file's metadata, the way a photo taken sideways does.
        CGImageDestinationAddImage(
            destination,
            makeMarkedImage(width: 80, height: 40),
            [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))

        let decoded = try #require(ImageOrientationCorrection.decodeUpright(data as Data))
        #expect(decoded.width == 40, "the declared rotation should have been applied")
        #expect(decoded.height == 80)
    }

    @Test("Undecodable data yields nil rather than an empty image")
    func rejectsGarbage() {
        #expect(ImageOrientationCorrection.decodeUpright(Data([0x01, 0x02, 0x03])) == nil)
    }
}
