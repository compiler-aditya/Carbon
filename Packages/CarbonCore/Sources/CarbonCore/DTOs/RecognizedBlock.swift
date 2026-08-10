/// A run of text on the page — a paragraph or a line — with where it sits.
///
/// Record-mode extraction is label-anchored: find the block whose text matches a field's
/// label, then read the nearest block to its right or below. That algorithm needs frames,
/// which is why blocks are not flattened to a single string.
public struct RecognizedBlock: Sendable, Codable, Hashable {
    public let text: String
    public let frame: NormalizedRect
    public let recognitionConfidence: Double

    public init(text: String, frame: NormalizedRect, recognitionConfidence: Double) {
        self.text = text
        self.frame = frame
        self.recognitionConfidence = recognitionConfidence
    }
}
