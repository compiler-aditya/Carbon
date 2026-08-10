import Foundation
import Testing

@testable import CarbonCore

@Suite("Snapshot layer")
struct SnapshotTests {
    private func value(
        _ key: String,
        raw: String = "x",
        normalized: String = "x",
        confidence: Double = 0.9,
        source: ExtractionSource = .deterministic
    ) -> ExtractedValue {
        ExtractedValue(
            fieldKey: key,
            rawText: raw,
            normalized: normalized,
            confidence: confidence,
            source: source,
            frame: nil
        )
    }

    @Test("A record is confirmed only when no value needs review")
    func statusFromValues() {
        let clean = ExtractedRecord(sourceRowIndex: 0, values: [value("a"), value("b")])
        #expect(clean.resolvedStatus == .confirmed)

        let doubtful = ExtractedRecord(
            sourceRowIndex: 0,
            values: [value("a"), value("b", confidence: 0.4)]
        )
        #expect(doubtful.resolvedStatus == .needsReview)
    }

    @Test("One unresolved field is enough to need review, whatever the others say")
    func unresolvedForcesReview() {
        let record = ExtractedRecord(
            sourceRowIndex: nil,
            values: [value("a"), .unresolved(fieldKey: "b")]
        )
        #expect(record.resolvedStatus == .needsReview)
        #expect(record.value(forKey: "b")?.band == .needsReview)
    }

    @Test("A missing field exports as empty, so every row has the same columns")
    func missingFieldExportsEmpty() {
        let record = RecordSnapshot(
            id: UUID(),
            capturedAt: .now,
            status: .confirmed,
            sourceRowIndex: nil,
            values: []
        )
        #expect(record.exportValue(forKey: "amount") == "")
        #expect(record.value(forKey: "amount") == nil)
    }

    @Test("A correction is an edit that actually changed the reading")
    func correctionDetection() {
        func snapshot(raw: String, normalized: String, edited: Bool) -> FieldValueSnapshot {
            FieldValueSnapshot(
                id: UUID(),
                fieldKey: "qty",
                rawText: raw,
                normalizedValue: normalized,
                confidence: 1.0,
                source: edited ? .userEntered : .deterministic,
                wasEditedByUser: edited,
                frame: nil
            )
        }
        // Confirming a correct reading is not a correction — it must not count against accuracy.
        #expect(!snapshot(raw: "14", normalized: "14", edited: true).wasCorrected)
        #expect(snapshot(raw: "l4", normalized: "14", edited: true).wasCorrected)
        #expect(!snapshot(raw: "14", normalized: "14", edited: false).wasCorrected)
    }

    @Test("Tier 1 share counts deterministic values across every record on the page")
    func deterministicShare() {
        let result = ExtractionResult(
            records: [
                ExtractedRecord(
                    sourceRowIndex: 0,
                    values: [value("a"), value("b", source: .model)]
                ),
                ExtractedRecord(
                    sourceRowIndex: 1,
                    values: [value("a"), value("b")]
                ),
            ],
            pageID: UUID(),
            durationMs: 12,
            engineVersion: "test",
            diagnostics: []
        )
        #expect(result.deterministicShare == 0.75)
    }

    @Test("An empty result reports no Tier 1 share rather than dividing by zero")
    func emptyShare() {
        let result = ExtractionResult(
            records: [], pageID: UUID(), durationMs: 0, engineVersion: "test", diagnostics: []
        )
        #expect(result.deterministicShare == 0)
    }

    @Test(
        "Period keys are zero-padded and month-aligned",
        arguments: [
            (DateComponents(year: 2026, month: 9, day: 30), "2026-09"),
            (DateComponents(year: 2026, month: 10, day: 1), "2026-10"),
            (DateComponents(year: 2026, month: 1, day: 31), "2026-01"),
        ]
    )
    func periodKeys(components: DateComponents, expected: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date = try #require(calendar.date(from: components))
        #expect(UsagePeriodSnapshot.periodKey(for: date, calendar: calendar) == expected)
    }
}
