import CarbonCore
import Foundation
import Testing

@testable import CorpusScoring

@Suite("Corpus scoring")
struct CorpusScoringTests {
    private func outcome(
        _ key: String,
        expected: String,
        actual: String,
        type: FieldType = .text,
        source: ExtractionSource = .deterministic
    ) -> FieldOutcome {
        FieldOutcome(fieldKey: key, type: type, expected: expected, actual: actual, source: source)
    }

    private func page(
        _ name: String,
        handwritten: Bool = false,
        rendered: Bool = false,
        records: [[FieldOutcome]],
        expectedRecords: Int? = nil,
        actualRecords: Int? = nil,
        latency: Duration = .milliseconds(500)
    ) -> PageResult {
        PageResult(
            imageName: name,
            isHandwritten: handwritten,
            isRendered: rendered,
            expectedRecordCount: expectedRecords ?? records.count,
            actualRecordCount: actualRecords ?? records.count,
            outcomesByRecord: records,
            latency: latency
        )
    }

    @Test("A record counts as clean only when every one of its fields is right")
    func recordsNeedingNoCorrection() {
        let report = CorpusReport(pages: [
            page("a", records: [
                [outcome("x", expected: "1", actual: "1"), outcome("y", expected: "2", actual: "2")],
                [outcome("x", expected: "3", actual: "3"), outcome("y", expected: "4", actual: "9")],
            ])
        ])
        // One of two records was perfect. A record with a single wrong field is a record the
        // user had to touch, and it does not count as clean.
        #expect(report.recordsNeedingNoCorrection() == 0.5)
    }

    @Test("Field precision counts values, not records")
    func fieldPrecision() {
        let report = CorpusReport(pages: [
            page("a", records: [
                [
                    outcome("x", expected: "1", actual: "1"),
                    outcome("y", expected: "2", actual: "2"),
                    outcome("z", expected: "3", actual: "9"),
                ]
            ])
        ])
        #expect(abs(report.fieldPrecision() - 2.0 / 3.0) < 0.0001)
    }

    @Test("Precision is reported per field type, because dates and text fail differently")
    func precisionByType() {
        let report = CorpusReport(pages: [
            page("a", records: [
                [
                    outcome("d1", expected: "01/04", actual: "01/04", type: .date),
                    outcome("d2", expected: "02/04", actual: "07/04", type: .date),
                    outcome("t1", expected: "Sugar", actual: "Sugar", type: .text),
                ]
            ])
        ])
        let byType = report.precisionByType()
        #expect(byType[.date] == 0.5)
        #expect(byType[.text] == 1.0)
    }

    @Test("Printed and handwritten are scored separately")
    func splitByHandwriting() {
        let report = CorpusReport(pages: [
            page("printed", handwritten: false, records: [
                [outcome("x", expected: "1", actual: "1")]
            ]),
            page("written", handwritten: true, records: [
                [outcome("x", expected: "1", actual: "7")]
            ]),
        ])
        #expect(report.fieldPrecision(handwritten: false) == 1.0)
        #expect(report.fieldPrecision(handwritten: true) == 0.0)
        #expect(report.fieldPrecision() == 0.5, "unfiltered is the blend of both")
    }

    @Test("Tier 1 share is the claim the architecture rests on")
    func tier1Share() {
        let report = CorpusReport(pages: [
            page("a", records: [
                [
                    outcome("x", expected: "1", actual: "1", source: .deterministic),
                    outcome("y", expected: "2", actual: "2", source: .deterministic),
                    outcome("z", expected: "3", actual: "3", source: .model),
                    outcome("w", expected: "4", actual: "", source: .unresolved),
                ]
            ])
        ])
        #expect(report.tier1Share() == 0.5)
        #expect(report.unresolvedShare() == 0.25)
    }

    @Test("A page where Carbon found the wrong number of rows is counted as such")
    func rowCountAccuracy() {
        let report = CorpusReport(pages: [
            page("good", records: [[outcome("x", expected: "1", actual: "1")]]),
            page(
                "short",
                records: [[outcome("x", expected: "1", actual: "1")]],
                expectedRecords: 14,
                actualRecords: 12
            ),
        ])
        #expect(report.rowCountAccuracy() == 0.5)
    }

    @Test("Latency percentiles come from the sorted set")
    func latency() {
        let report = CorpusReport(pages: (1...10).map { index in
            page("p\(index)", records: [], latency: .milliseconds(index * 100))
        })
        #expect(report.medianLatency() == .milliseconds(600))
        #expect(report.p95Latency() == .milliseconds(1000))
    }

    @Test("The most-missed fields make 'where it fails' specific")
    func mostMissed() {
        let report = CorpusReport(pages: [
            page("a", records: [
                [
                    outcome("amount", expected: "1", actual: "7"),
                    outcome("amount2", expected: "1", actual: "1"),
                ],
                [
                    outcome("amount", expected: "2", actual: "8"),
                    outcome("amount2", expected: "2", actual: "2"),
                ],
            ])
        ])
        let missed = report.mostMissedFields()
        #expect(missed.first?.fieldKey == "amount")
        #expect(missed.first?.missRate == 1.0)
        #expect(missed.count == 1, "fields that never missed do not appear")
    }

    @Test("An empty corpus reports zero rather than dividing by it")
    func emptyCorpus() {
        let report = CorpusReport(pages: [])
        #expect(report.fieldPrecision() == 0)
        #expect(report.recordsNeedingNoCorrection() == 0)
        #expect(report.medianLatency() == .zero)
        #expect(report.mostMissedFields().isEmpty)
    }

    // MARK: Alignment

    @Test("A row Carbon never found is scored as unresolved, not skipped")
    func missingRowsAreScored() {
        let template = TemplateSnapshot(
            id: UUID(), name: "R", mode: .table, dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [
                FieldSnapshot(
                    id: UUID(), key: "item", label: "Item", type: .text, isRequired: false,
                    aliases: [], choices: [], defaultValue: nil, currencyCode: nil,
                    validationPattern: nil, lastKnownFrame: nil
                )
            ],
            learnedHeaderAliases: []
        )

        let outcomes = CorpusRunner.compare(
            expected: [["item": "Sugar"], ["item": "Tea"]],
            actual: [
                ExtractedRecord(
                    sourceRowIndex: 0,
                    values: [
                        ExtractedValue(
                            fieldKey: "item", rawText: "Sugar", normalized: "Sugar",
                            confidence: 0.9, source: .deterministic, frame: nil
                        )
                    ]
                )
            ],
            template: template
        )

        #expect(outcomes.count == 2, "both expected rows are scored")
        #expect(outcomes[0][0].isCorrect)
        // The row that was never found is a row the user has to type. Dropping it would
        // flatter the number.
        #expect(!outcomes[1][0].isCorrect)
        #expect(outcomes[1][0].source == .unresolved)
    }

    @Test("A field the collector did not type is not scored against")
    func untypedFieldsAreSkipped() {
        let template = TemplateSnapshot(
            id: UUID(), name: "R", mode: .record, dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: ["item", "notes"].map { key in
                FieldSnapshot(
                    id: UUID(), key: key, label: key, type: .text, isRequired: false,
                    aliases: [], choices: [], defaultValue: nil, currencyCode: nil,
                    validationPattern: nil, lastKnownFrame: nil
                )
            },
            learnedHeaderAliases: []
        )

        let outcomes = CorpusRunner.compare(
            expected: [["item": "Sugar"]],
            actual: [ExtractedRecord(sourceRowIndex: 0, values: [])],
            template: template
        )
        #expect(outcomes[0].count == 1, "notes had no ground truth, so it is not scored")
    }

    // MARK: Formatting

    @Test("Percentages are truncated, never rounded in our favour")
    func percentagesTruncate() {
        // 0.6789 is 67.89%, which must not print as 67.9%.
        #expect(CorpusReportFormatter.percent(0.6789) == "67.8%")
        #expect(CorpusReportFormatter.percent(1.0) == "100.0%")
        #expect(CorpusReportFormatter.percent(0) == "0.0%")
    }

    @Test("A slice with no pages prints an em dash, never a misleading zero")
    func absentDataIsNotZero() {
        let printedOnly = CorpusReport(pages: [
            page("a", handwritten: false, records: [[outcome("x", expected: "1", actual: "1")]])
        ])
        let markdown = CorpusReportFormatter.markdown(printedOnly)

        #expect(markdown.contains("| Records needing no correction | 100.0% | — |"))
        #expect(
            !markdown.contains("| 100.0% | 0.0% |"),
            "no handwritten pages means not measured, not measured-as-failing"
        )
        #expect(markdown.contains("1 photograph**"), "singular when there is one page")
    }

    @Test("The markdown table carries the rows the README expects")
    func markdownShape() {
        let report = CorpusReport(pages: [
            page("a", records: [[outcome("x", expected: "1", actual: "1")]])
        ])
        let markdown = CorpusReportFormatter.markdown(report)

        #expect(markdown.contains("| Metric | Printed forms | Handwritten |"))
        #expect(markdown.contains("Records needing no correction"))
        #expect(markdown.contains("Field-level precision"))
        #expect(markdown.contains("Resolved by Tier 1 alone"))
    }

    /// The report is written to be pasted into the README, so it has to carry its own caveat.
    /// A run with nothing photographed behind it must not be pasteable as an accuracy claim.
    @Test("A report with no photographs in it refuses to read as an accuracy measurement")
    func renderedOnlyReportsSaySo() {
        let report = CorpusReport(pages: [
            page("drawn", rendered: true, records: [[outcome("x", expected: "1", actual: "1")]])
        ])
        let markdown = CorpusReportFormatter.markdown(report)

        #expect(markdown.contains("Not an accuracy measurement"))
        #expect(markdown.contains("1 rendered page"))
        // The word itself is the trap: "1 photograph" above a table of 100%s is the sentence
        // that would do the damage, and no page here was photographed.
        #expect(!markdown.contains("photograph**"))
    }

    @Test("A report with photographs behind it carries no such caveat")
    func photographedReportsAreUnqualified() {
        let report = CorpusReport(pages: [
            page("shot", records: [[outcome("x", expected: "1", actual: "1")]])
        ])
        let markdown = CorpusReportFormatter.markdown(report)

        #expect(!markdown.contains("Not an accuracy measurement"))
        #expect(markdown.contains("1 photograph"))
    }

    @Test("A mixed corpus names both, and still qualifies itself")
    func mixedCorpusNamesBoth() {
        let report = CorpusReport(pages: [
            page("shot", records: [[outcome("x", expected: "1", actual: "1")]]),
            page("drawn", rendered: true, records: [[outcome("x", expected: "1", actual: "1")]]),
        ])
        let markdown = CorpusReportFormatter.markdown(report)

        #expect(markdown.contains("1 photograph and 1 rendered page"))
        // One real photograph is a thin corpus, but it is a corpus. The caveat is for having
        // none at all.
        #expect(!markdown.contains("Not an accuracy measurement"))
    }
}
