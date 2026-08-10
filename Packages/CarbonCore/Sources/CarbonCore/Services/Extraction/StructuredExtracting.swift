/// Turns a recognised page plus a template into records.
///
/// The whole Tier 1 → 2 → 3 ladder lives behind this one call, and it is deliberately
/// non-throwing: there is no input for which the correct answer is an error. A page with
/// nothing on it yields records whose values are all `.unresolved`, which the review screen
/// presents as fields waiting to be filled in. That is a normal outcome and the copy must
/// not treat it as a failure.
public protocol StructuredExtracting: Sendable {
    func extract(page: RecognizedPage, template: TemplateSnapshot) async -> ExtractionResult
}
