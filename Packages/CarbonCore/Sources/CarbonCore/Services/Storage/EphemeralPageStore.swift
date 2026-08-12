import CoreGraphics
import Foundation

/// Keeps pages in memory for the lifetime of the process.
///
/// The last resort for when Application Support cannot be reached. Scans that live only for the
/// session is a bad outcome; refusing to launch is a worse one, and everything except the source
/// photograph keeps working — records, review, the dataset and export are all unaffected.
///
/// **This exists so the app does not fall back to a test fake.** It previously used
/// `FakePageStore`, which fabricates a blank page on `load` — so a user in this state would have
/// been shown a blank rectangle where their photograph should be, which is worse than being told
/// the page is gone. Here a page that was never stored throws, and the review screen already
/// handles that by saying the photograph is unavailable.
public actor EphemeralPageStore: PageStoring {
    private var pages: [PageRef: CGImage] = [:]

    public init() {}

    @discardableResult
    public func persist(_ image: CGImage, captureID: UUID, pageIndex: Int) async throws -> PageRef {
        let ref = PageRef(captureID: captureID, pageIndex: pageIndex)
        pages[ref] = image
        return ref
    }

    public func load(_ ref: PageRef) async throws -> CGImage {
        guard let image = pages[ref] else {
            throw CarbonError.pageWriteFailed(underlying: "no page in memory at \(ref.relativePath)")
        }
        return image
    }

    public func delete(_ ref: PageRef) async throws {
        pages[ref] = nil
    }

    public func deleteAll(captureID: UUID) async throws {
        pages = pages.filter { $0.key.captureID != captureID }
    }

    /// What the images actually occupy, not a plausible-looking guess. Settings shows this
    /// number to someone deciding whether to delete their scans, so inventing it would be a
    /// small lie in the one place the user is being asked to make a storage decision.
    public func totalBytes() async throws -> Int {
        pages.values.reduce(0) { $0 + $1.height * $1.bytesPerRow }
    }
}
