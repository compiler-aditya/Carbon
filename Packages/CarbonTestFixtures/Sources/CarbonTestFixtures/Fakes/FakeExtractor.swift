import CarbonCore
import Foundation

/// Produces records straight from the page's table, matching columns by position.
///
/// Not a reimplementation of Tier 1 — it is deliberately dumber, so that a screen built
/// against it cannot accidentally depend on real matching behaviour. It exists to give the
/// interface realistic data to draw, including the mixed confidences that make the review
/// screen worth looking at.
public actor FakeExtractor: StructuredExtracting {
    private let delay: Duration

    public init(delay: Duration = .zero) {
        self.delay = delay
    }

    public func extract(page: RecognizedPage, template: TemplateSnapshot) async -> ExtractionResult {
        if delay > .zero { try? await Task.sleep(for: delay) }

        let records: [ExtractedRecord] =
            switch template.mode {
            case .table: tableRecords(page: page, template: template)
            case .record: [recordModeRecord(page: page, template: template)]
            }

        return ExtractionResult(
            records: records,
            pageID: page.pageID,
            durationMs: 42,
            engineVersion: "fake-1",
            diagnostics: ["FakeExtractor: matched \(template.fields.count) fields by position"]
        )
    }

    private func tableRecords(page: RecognizedPage, template: TemplateSnapshot) -> [ExtractedRecord] {
        guard let table = page.primaryTable else { return [] }
        return table.dataRows.enumerated().map { rowIndex, row in
            ExtractedRecord(
                sourceRowIndex: rowIndex,
                values: template.fields.enumerated().map { columnIndex, field in
                    guard columnIndex < row.count else { return .unresolved(fieldKey: field.key) }
                    let cell = row[columnIndex]
                    guard !cell.text.isEmpty else { return .unresolved(fieldKey: field.key) }
                    return ExtractedValue(
                        fieldKey: field.key,
                        rawText: cell.text,
                        normalized: cell.text,
                        confidence: cell.recognitionConfidence,
                        source: .deterministic,
                        frame: cell.frame
                    )
                }
            )
        }
    }

    private func recordModeRecord(page: RecognizedPage, template: TemplateSnapshot) -> ExtractedRecord {
        ExtractedRecord(
            sourceRowIndex: nil,
            values: template.fields.map { field in
                guard
                    let block = page.blocks.first(where: {
                        $0.text.localizedCaseInsensitiveContains(field.label)
                    })
                else {
                    return .unresolved(fieldKey: field.key)
                }
                return ExtractedValue(
                    fieldKey: field.key,
                    rawText: block.text,
                    normalized: block.text,
                    confidence: block.recognitionConfidence,
                    source: .deterministic,
                    frame: block.frame
                )
            }
        )
    }
}
