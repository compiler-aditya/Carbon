/// A rectangle on a page, normalised 0–1, **origin top-left**.
///
/// Vision reports normalised geometry with a bottom-left origin. The flip happens once, at
/// the recognition boundary, so that everything above it — persistence, review, tap-to-zoom —
/// shares SwiftUI's coordinate sense. Converting in more than one place is how a zoom target
/// ends up mirrored vertically.
public struct NormalizedRect: Sendable, Codable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var midY: Double { y + height / 2 }
    public var maxX: Double { x + width }

    /// The smallest rectangle containing both. Used to grow a field's zoom target to cover
    /// every line that contributed to its value.
    public func union(_ other: NormalizedRect) -> NormalizedRect {
        let minX = Swift.min(x, other.x)
        let minY = Swift.min(y, other.y)
        return NormalizedRect(
            x: minX,
            y: minY,
            width: Swift.max(maxX, other.maxX) - minX,
            height: Swift.max(y + height, other.y + other.height) - minY
        )
    }
}
