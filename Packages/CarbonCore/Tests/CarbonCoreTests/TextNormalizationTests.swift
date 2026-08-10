import Foundation
import Testing

@testable import CarbonCore

@Suite("Text normalization")
struct TextNormalizationTests {
    @Test(
        "Whitespace is trimmed and collapsed",
        arguments: [
            ("  Basmati rice 5kg  ", "Basmati rice 5kg"),
            ("Mustard\toil", "Mustard oil"),
            ("Wheat   flour\n10kg", "Wheat flour 10kg"),
        ]
    )
    func whitespace(input: String, expected: String) {
        #expect(TextNormalization.normalizeText(input).text == expected)
    }

    @Test(
        "Isolated OCR artefacts are dropped",
        arguments: [
            ("| Turmeric powder |", "Turmeric powder"),
            ("~ Sugar 1kg", "Sugar 1kg"),
            ("Tea leaves † 500g", "Tea leaves 500g"),
        ]
    )
    func isolatedArtefacts(input: String, expected: String) {
        #expect(TextNormalization.normalizeText(input).text == expected)
    }

    @Test("An artefact character inside a word is left alone — it may be real")
    func embeddedCharactersSurvive() {
        #expect(TextNormalization.normalizeText("A|B").text == "A|B")
        #expect(TextNormalization.normalizeText("N/A~1").text == "N/A~1")
    }

    @Test("An identifier is trimmed and otherwise untouched")
    func identifiersAreNotCleaned() {
        // Collapsing this whitespace or stripping the bar would stop it matching the
        // customer's own records, which is the entire purpose of the field.
        #expect(TextNormalization.normalizeIdentifier("  INV  2026/041  ").text == "INV  2026/041")
        #expect(TextNormalization.normalizeIdentifier("A|B-0091").text == "A|B-0091")
        #expect(TextNormalization.normalizeIdentifier("inv-77").text == "inv-77")
    }

    @Test(
        "Phone numbers keep their digits and a leading plus",
        arguments: [
            ("+91 98765 43210", "+919876543210"),
            ("(022) 2654-1100", "02226541100"),
            ("98765 43210", "9876543210"),
        ]
    )
    func phones(input: String, expected: String) {
        let result = TextNormalization.normalizePhone(input)
        #expect(result.text == expected)
        #expect(result.isWellFormed)
    }

    @Test("Too few digits to be a phone number is kept but flagged")
    func shortPhoneIsFlagged() {
        let result = TextNormalization.normalizePhone("1234")
        #expect(result.text == "1234", "never discard what was written on the page")
        #expect(!result.isWellFormed)
    }

    @Test("Nothing usable is empty, for every text-shaped type", arguments: ["", "   ", "|", "~ |"])
    func emptyInputs(input: String) {
        #expect(TextNormalization.normalizeText(input) == .empty)
        #expect(TextNormalization.normalizePhone(input) == .empty)
    }

    @Test("The normalizer routes each type to its own rules")
    func dispatch() {
        let normalizer = StandardNormalizer()
        let rules = NormalizationRules()

        #expect(normalizer.normalize(" 1,200.50 ", as: .currency, using: rules).text == "1200.50")
        #expect(normalizer.normalize("12.5", as: .integer, using: rules).text == "12")
        #expect(normalizer.normalize("  INV  041 ", as: .identifier, using: rules).text == "INV  041")
        #expect(normalizer.normalize("| Sugar |", as: .text, using: rules).text == "Sugar")
    }
}
