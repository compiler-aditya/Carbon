import CoreGraphics
import Foundation

/// Reads the structure of a page: text with frames, tables with rows and columns, and
/// detected data.
///
/// A `CGImage` goes in and one of our own value types comes out. Nothing framework-typed
/// crosses this boundary, which is what lets the whole extraction ladder be tested from
/// recorded fixtures with no camera and no Vision.
public protocol Recognizing: Sendable {
    func recognize(_ image: CGImage, pageID: UUID) async throws -> RecognizedPage
}
