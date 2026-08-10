import CarbonCore
import CoreGraphics
import Foundation

/// In-memory page store. Records what it was asked to keep so tests can assert that pages
/// were persisted before processing, and that deleting a record removes its files.
public actor FakePageStore: PageStoring {
    private var stored: [PageRef: CGSize] = [:]

    /// Set to make `persist` throw, for exercising the write-failure path.
    public var failureToThrow: (any Error)?

    public init(failureToThrow: (any Error)? = nil) {
        self.failureToThrow = failureToThrow
    }

    public func setFailure(_ error: (any Error)?) {
        failureToThrow = error
    }

    public var storedRefs: [PageRef] { Array(stored.keys) }

    @discardableResult
    public func persist(_ image: CGImage, captureID: UUID, pageIndex: Int) async throws -> PageRef {
        if let failureToThrow { throw failureToThrow }
        let ref = PageRef(captureID: captureID, pageIndex: pageIndex)
        stored[ref] = CGSize(width: image.width, height: image.height)
        return ref
    }

    public func load(_ ref: PageRef) async throws -> CGImage {
        guard let size = stored[ref] else {
            throw CarbonError.pageWriteFailed(underlying: "no page at \(ref.relativePath)")
        }
        return Self.makeImage(width: Int(size.width), height: Int(size.height))
    }

    public func delete(_ ref: PageRef) async throws {
        stored[ref] = nil
    }

    public func deleteAll(captureID: UUID) async throws {
        stored = stored.filter { $0.key.captureID != captureID }
    }

    public func totalBytes() async throws -> Int {
        // A plausible figure rather than a real one — enough for the Storage section in
        // Settings to render something believable in a preview.
        stored.count * 480_000
    }

    /// A blank page in the app's paper colour. Enough for a preview to show a thumbnail.
    public static func makeImage(width: Int = 1240, height: Int = 1754) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(red: 0.929, green: 0.929, blue: 0.894, alpha: 1)
        context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage() ?? emptyImage
    }

    private static let emptyImage: CGImage = {
        let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return context!.makeImage()!
    }()
}
