/// The result of normalising one raw string against its declared field type.
public struct NormalizedValue: Sendable, Hashable {
    /// Canonical form. All reads and exports use this. Empty when nothing could be made of
    /// the input — which is a normal outcome and not an error.
    public let text: String

    /// Applied to the incoming confidence, 0...1.
    ///
    /// Ambiguity lowers confidence instead of picking a winner. A number that could be read
    /// two ways, or a choice that is not close enough to any declared option, comes back
    /// with the raw text preserved and a reduced score, so it surfaces for review rather
    /// than being silently guessed at.
    public let confidenceMultiplier: Double

    /// Whether the value parsed cleanly as its declared type.
    public let isWellFormed: Bool

    public init(text: String, confidenceMultiplier: Double, isWellFormed: Bool) {
        self.text = text
        self.confidenceMultiplier = confidenceMultiplier
        self.isWellFormed = isWellFormed
    }

    /// Parsed exactly, no doubt about it.
    public static func exact(_ text: String) -> NormalizedValue {
        NormalizedValue(text: text, confidenceMultiplier: 1.0, isWellFormed: true)
    }

    /// Readable, but with something ambiguous about it. Keeps the text and drops the score.
    public static func uncertain(_ text: String, multiplier: Double) -> NormalizedValue {
        NormalizedValue(text: text, confidenceMultiplier: multiplier, isWellFormed: false)
    }

    /// Nothing usable. Never silently drops the user's data — the caller keeps `rawText`.
    public static let empty = NormalizedValue(
        text: "", confidenceMultiplier: 0, isWellFormed: false
    )
}
