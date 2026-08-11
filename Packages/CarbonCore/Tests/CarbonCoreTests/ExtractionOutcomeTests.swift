import Foundation
import Testing

@testable import CarbonCore

/// The rule that decides whether a page produced anything worth keeping.
///
/// This is the difference between the app's worst dead end — a scan that quietly returns you
/// to where you started — and a sentence telling you the template is wrong. The threshold is
/// deliberately "nothing at all", not "some fields missing": a half-read page is a normal
/// outcome the review screen exists to handle.
@Suite("Empty extraction outcomes")
struct ExtractionOutcomeTests {
    private func template(_ mode: TemplateMode) -> TemplateSnapshot {
        TemplateSnapshot(
            id: UUID(), name: "Register", mode: mode,
            dateConvention: .dayMonthYear, preferredDateFormat: nil,
            fields: [
                FieldSnapshot(
                    id: UUID(), key: "item", label: "Item", type: .text, isRequired: false,
                    aliases: [], choices: [], defaultValue: nil, currencyCode: nil,
                    validationPattern: nil, lastKnownFrame: nil
                )
            ],
            learnedHeaderAliases: []
        )
    }

    private func result(_ records: [ExtractedRecord]) -> ExtractionResult {
        ExtractionResult(
            records: records, pageID: UUID(), durationMs: 1,
            engineVersion: "test", diagnostics: []
        )
    }

    private func value(_ source: ExtractionSource, _ text: String = "Sugar 1kg") -> ExtractedValue {
        ExtractedValue(
            fieldKey: "item", rawText: text, normalized: text,
            confidence: source == .unresolved ? 0 : 0.9, source: source, frame: nil
        )
    }

    @Test("A table template that met no table says so specifically")
    func tableModeWithNoRows() {
        #expect(result([]).emptyOutcome(for: template(.table)) == .noTableFound)
    }

    @Test("A record template that produced nothing reads as the wrong template")
    func recordModeWithNoRecords() {
        #expect(result([]).emptyOutcome(for: template(.record)) == .noFieldsMatched)
    }

    @Test("One value read off the page is enough to keep the record")
    func anythingReadIsKept() {
        let record = ExtractedRecord(sourceRowIndex: nil, values: [value(.deterministic)])
        #expect(result([record]).emptyOutcome(for: template(.record)) == nil)
        #expect(result([record]).emptyOutcome(for: template(.table)) == nil)
    }

    @Test("A value the model resolved counts as read")
    func modelValuesCount() {
        let record = ExtractedRecord(sourceRowIndex: nil, values: [value(.model)])
        #expect(result([record]).emptyOutcome(for: template(.record)) == nil)
    }

    @Test("A record of nothing but unresolved fields is the wrong template, not a record")
    func allUnresolvedIsNotARecord() {
        let record = ExtractedRecord(
            sourceRowIndex: nil, values: [ExtractedValue.unresolved(fieldKey: "item")]
        )
        #expect(result([record]).emptyOutcome(for: template(.record)) == .noFieldsMatched)
    }

    /// The subtle one. A template default is something *we* supplied, so a record made only of
    /// defaults looks populated while containing nothing the page actually said — and saving it
    /// would put a row of invented data into the dataset the whole product is about.
    @Test("Template defaults alone do not count as having read the page")
    func defaultsAreNotReading() {
        let record = ExtractedRecord(sourceRowIndex: nil, values: [value(.defaultValue, "cash")])
        #expect(result([record]).emptyOutcome(for: template(.record)) == .noFieldsMatched)
    }

    @Test("Rows of nothing from a matched-no-columns table are refused too")
    func tableRowsWithNothingInThem() {
        let rows = (0..<3).map { index in
            ExtractedRecord(
                sourceRowIndex: index, values: [ExtractedValue.unresolved(fieldKey: "item")]
            )
        }
        #expect(result(rows).emptyOutcome(for: template(.table)) == .noFieldsMatched)
    }

    @Test("Whatever comes back, it is something the user can act on")
    func everyOutcomeIsActionable() {
        for outcome in [CarbonError.noTableFound, .noFieldsMatched] {
            #expect(outcome.isUserFacing)
            #expect(outcome.recovery == .retry)
        }
    }
}
