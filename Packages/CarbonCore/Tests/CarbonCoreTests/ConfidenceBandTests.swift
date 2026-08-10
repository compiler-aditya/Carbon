import Testing

@testable import CarbonCore

@Suite("Confidence banding")
struct ConfidenceBandTests {
    @Test(
        "Scores land in the documented band",
        arguments: [
            (1.0, ConfidenceBand.high),
            (0.86, .high),
            (0.85, .high),      // boundary is inclusive at the top
            (0.849, .medium),
            (0.60, .medium),    // boundary is inclusive at the top
            (0.599, .needsReview),
            (0.0, .needsReview),
        ]
    )
    func banding(score: Double, expected: ConfidenceBand) {
        #expect(ConfidenceBand(confidence: score, source: .deterministic) == expected)
    }

    @Test("Unresolved always needs review, whatever the score claims")
    func unresolvedOverridesScore() {
        #expect(ConfidenceBand(confidence: 1.0, source: .unresolved) == .needsReview)
    }

    @Test("A user edit is high confidence")
    func userEntered() {
        #expect(ConfidenceBand(confidence: 1.0, source: .userEntered) == .high)
    }
}
