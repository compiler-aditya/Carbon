import Foundation

/// Tier 2: asks the on-device model to fill in the fields Tier 1 could not.
///
/// A protocol so the ladder's merging logic is testable without a model — which matters,
/// because that merging is where the interesting decisions live and the model is unavailable
/// on a simulator and in CI.
public protocol ModelFieldResolving: Sendable {
    /// - Parameters:
    ///   - fields: only those still needing a value. Never the whole template — the point of
    ///     the tier is that it handles the remainder.
    ///   - pageText: the page's reading-order transcript. **Never the image.**
    /// - Returns: values by field key. A field the model could not place is simply absent,
    ///   which the ladder reads as Tier 3.
    func resolve(
        fields: [FieldSnapshot],
        pageText: String,
        template: TemplateSnapshot
    ) async throws -> [String: String]
}

/// The confidence ceiling for anything the model produced.
///
/// Deliberately below `ConfidenceThreshold.high`, so a model-derived value can never render
/// on a solid rule. A matched column header is stronger evidence than an inference from
/// prose, and the interface should say so without the user having to know why.
public enum ModelConfidence {
    public static let ceiling = 0.84
}
