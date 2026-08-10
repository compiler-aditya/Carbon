import Foundation
import Testing

@testable import CarbonCore

@Suite("Number normalization")
struct NumberNormalizationTests {
    @Test(
        "Both decimal conventions resolve to the same canonical value",
        arguments: [
            ("1,200.50", "1200.50"),   // comma thousands, dot decimal
            ("1.200,50", "1200.50"),   // dot thousands, comma decimal
            ("1,234,567.89", "1234567.89"),
            ("1.234.567,89", "1234567.89"),
            ("12,50", "12.50"),        // one separator, two digits after: decimal
            ("12.50", "12.50"),
            ("0,5", "0.5"),
            ("560.00", "560.00"),
        ]
    )
    func decimalConventions(input: String, expected: String) {
        let result = NumberNormalization.normalizeDecimal(input)
        #expect(result.text == expected)
        #expect(result.isWellFormed)
    }

    @Test(
        "A single separator with three digits after it is ambiguous, so confidence drops",
        arguments: [("1,200", "1200"), ("1.200", "1200"), ("12,345", "12345")]
    )
    func ambiguousGroupsLoseConfidence(input: String, expected: String) {
        let result = NumberNormalization.normalizeDecimal(input)
        // Read as thousands, which is right far more often on a register…
        #expect(result.text == expected)
        // …but never silently. It surfaces for review instead of being decided quietly.
        #expect(!result.isWellFormed)
        #expect(result.confidenceMultiplier < 1.0)
    }

    @Test("Two digits after a separator is unambiguously a decimal, and keeps full confidence")
    func twoDigitGroupIsNotAmbiguous() {
        let result = NumberNormalization.normalizeDecimal("12,50")
        #expect(result.text == "12.50")
        #expect(result.confidenceMultiplier == 1.0)
    }

    @Test(
        "Currency symbols and unit suffixes carry no numeric information",
        arguments: [
            ("₹1,200.50", "1200.50"),
            ("$ 45.00", "45.00"),
            ("£99.99", "99.99"),
            ("€ 1.234,56", "1234.56"),
        ]
    )
    func currencyMarkersAreStripped(input: String, expected: String) {
        #expect(NumberNormalization.normalizeCurrency(input).text == expected)
    }

    @Test("A declared unit suffix is stripped before parsing")
    func unitSuffixStripped() {
        #expect(NumberNormalization.normalizeDecimal("12.5 kg", unitSuffix: "kg").text == "12.5")
        #expect(NumberNormalization.normalizeDecimal("8 hrs", unitSuffix: "hrs").text == "8")
    }

    @Test(
        "Negatives are recognised in both the minus and the bracket form",
        arguments: [("-450", "-450"), ("(450)", "-450"), ("-1,200.50", "-1200.50")]
    )
    func negatives(input: String, expected: String) {
        #expect(NumberNormalization.normalizeDecimal(input).text == expected)
    }

    @Test("Leading zeros are dropped from the whole part")
    func leadingZeros() {
        #expect(NumberNormalization.normalizeDecimal("007").text == "7")
        #expect(NumberNormalization.normalizeDecimal("0012.50").text == "12.50")
    }

    @Test("An integer field keeps a fractional value but flags it rather than truncating quietly")
    func integerWithFraction() {
        let result = NumberNormalization.normalizeInteger("12.5")
        #expect(result.text == "12")
        #expect(!result.isWellFormed, "silently dropping .5 from a declared count changes the data")
    }

    @Test("A clean integer parses exactly", arguments: ["12", "1,200", "0"])
    func cleanIntegers(input: String) {
        #expect(!NumberNormalization.normalizeInteger(input).text.contains("."))
    }

    @Test(
        "Nothing numeric yields an empty value rather than a wrong one",
        arguments: ["", "   ", "—", "n/a", "abc"]
    )
    func nonNumericIsEmpty(input: String) {
        #expect(NumberNormalization.normalizeDecimal(input) == .empty)
    }

    @Test("OCR artefacts around a number do not defeat it")
    func artefactsAreTolerated() {
        #expect(NumberNormalization.normalizeDecimal("| 560.00 |").text == "560.00")
        #expect(NumberNormalization.normalizeCurrency("~ ₹1,484.00").text == "1484.00")
    }
}
