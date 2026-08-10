import CarbonCore
import Foundation

/// Trims and collapses whitespace, and nothing else.
///
/// Deliberately not a second implementation of the real normalizer. A fake that quietly
/// reimplements the thing under test is how a suite ends up passing against behaviour that
/// does not exist.
public struct FakeNormalizer: Normalizing {
    public init() {}

    public func normalize(
        _ raw: String,
        as type: FieldType,
        using rules: NormalizationRules
    ) -> NormalizedValue {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return cleaned.isEmpty ? .empty : .exact(cleaned)
    }
}
