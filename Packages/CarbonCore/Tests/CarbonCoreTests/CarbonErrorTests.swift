import Foundation
import Testing

@testable import CarbonCore

@Suite("Error taxonomy")
struct CarbonErrorTests {
    /// Every case, so a newly added one cannot ship without copy.
    private static let allCases: [CarbonError] = [
        .cameraUnavailable,
        .cameraPermissionDenied,
        .pageWriteFailed(underlying: "disk full"),
        .recognitionFailed(pageIndex: 0),
        .noTableFound,
        .noFieldsMatched,
        .modelUnavailable(reason: .deviceNotEligible),
        .modelUnavailable(reason: .appleIntelligenceNotEnabled),
        .modelUnavailable(reason: .modelNotReady),
        .modelUnavailable(reason: .unsupportedLanguage),
        .modelTimedOut,
        .exportFailed(underlying: "no space"),
    ]

    @Test("Every case resolves to real copy", arguments: allCases)
    func copyResolves(error: CarbonError) {
        #expect(!String(localized: error.title).isEmpty)
        #expect(!String(localized: error.guidance).isEmpty)
    }

    @Test("Copy never leaks the underlying system message to the user", arguments: allCases)
    func noUnderlyingLeak(error: CarbonError) {
        // "disk full" and "no space" are diagnostic strings for the log, not for a person
        // staring at a scan that did not work.
        #expect(!String(localized: error.title).contains("disk full"))
        #expect(!String(localized: error.guidance).contains("no space"))
    }

    @Test("Page numbers are shown 1-based")
    func pageNumbersAreOneBased() {
        #expect(String(localized: CarbonError.recognitionFailed(pageIndex: 0).title).contains("1"))
        #expect(String(localized: CarbonError.recognitionFailed(pageIndex: 3).title).contains("4"))
    }

    @Test("Model problems never interrupt the user")
    func modelProblemsAreNotUserFacing() {
        #expect(!CarbonError.modelTimedOut.isUserFacing)
        #expect(!CarbonError.modelUnavailable(reason: .modelNotReady).isUserFacing)
        #expect(CarbonError.noTableFound.isUserFacing)
        #expect(CarbonError.cameraPermissionDenied.isUserFacing)
    }

    @Test("Only a still-downloading model is worth re-checking later")
    func transience() {
        #expect(ModelUnavailableReason.modelNotReady.isTransient)
        for reason in ModelUnavailableReason.allCases where reason != .modelNotReady {
            #expect(!reason.isTransient)
        }
    }

    @Test("No user-facing copy uses the vocabulary the spec bans", arguments: allCases)
    func vocabulary(error: CarbonError) {
        // Whole words only. A substring match would flag "AI" inside "available" and
        // "again", which is how a well-meant lint rule gets deleted in week two.
        let banned: Set<String> = [
            "ai", "ocr", "llm", "magic", "smart", "effortless", "oops", "sorry", "unfortunately",
        ]
        let copy = "\(String(localized: error.title)) \(String(localized: error.guidance))"
        let words = Set(
            copy.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
        )
        let offenders = words.intersection(banned)
        #expect(offenders.isEmpty, "\(error) copy uses banned vocabulary: \(offenders.sorted())")
    }
}

/// Lets `CarbonError` be used as a parameterised-test argument, so a failure names the case
/// rather than an index.
extension CarbonError: CustomTestArgumentEncodable {
    public func encodeTestArgument(to encoder: some Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(describing: self))
    }
}
