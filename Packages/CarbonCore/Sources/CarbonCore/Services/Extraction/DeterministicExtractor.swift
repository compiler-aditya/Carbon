import Foundation

/// Tier 1: pure Swift, no model.
///
/// Fast, free, fully testable, and correct for the common case of a clean printed form. It
/// always runs first, and on a good scan of a printed register it resolves everything — the
/// model exists for what is left over, not for the main path.
///
/// Never throws. A page it cannot read yields unresolved values, which the review screen
/// presents as fields waiting to be filled in.
public struct DeterministicExtractor: StructuredExtracting {
    public static let engineVersion = "vision-doc-1|tier1-1|norm-1"

    private let normalizer: any Normalizing

    public init(normalizer: any Normalizing = StandardNormalizer()) {
        self.normalizer = normalizer
    }

    public func extract(page: RecognizedPage, template: TemplateSnapshot) async -> ExtractionResult {
        let started = ContinuousClock.now

        let records: [ExtractedRecord]
        var diagnostics: [String] = []
        var aliasesToLearn: [String: String] = [:]

        switch template.mode {
        case .table:
            (records, diagnostics, aliasesToLearn) = tableRecords(page: page, template: template)
        case .record:
            (records, diagnostics) = ([recordModeRecord(page: page, template: template)], [])
        }

        let elapsed = started.duration(to: .now)
        return ExtractionResult(
            records: records,
            pageID: page.pageID,
            durationMs: Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000),
            engineVersion: Self.engineVersion,
            diagnostics: diagnostics,
            aliasesToLearn: aliasesToLearn
        )
    }

    // MARK: Table mode

    private func tableRecords(
        page: RecognizedPage,
        template: TemplateSnapshot
    ) -> ([ExtractedRecord], [String], [String: String]) {
        guard let table = page.primaryTable else {
            return ([], ["no table found on page"], [:])
        }

        var diagnostics: [String] = []
        let matches: [ColumnMatcher.Match]

        if let header = table.headerRow {
            matches = ColumnMatcher.match(headerRow: header, fields: template.fields)
            diagnostics.append("matched \(matches.count) of \(template.fields.count) fields by header")

            let unmatched = template.fields
                .filter { field in !matches.contains { $0.fieldKey == field.key } }
                .map(\.key)
            if !unmatched.isEmpty {
                diagnostics.append("unmatched fields: \(unmatched.joined(separator: ", "))")
            }
        } else {
            // No header on the page. Read columns in declared order and score every value as
            // a guess, so the whole page lands in review rather than looking authoritative.
            let width = table.rows.map(\.count).max() ?? 0
            matches = ColumnMatcher.positionalMatches(columnCount: width, fields: template.fields)
            diagnostics.append("no header row; matched \(matches.count) fields positionally")
        }

        let records = table.dataRows.enumerated().map { rowIndex, row in
            ExtractedRecord(
                sourceRowIndex: rowIndex,
                values: template.fields.map { field in
                    value(for: field, in: row, matches: matches, template: template)
                }
            )
        }

        // Only inexact matches are worth remembering. A header that already matched a
        // declared alias exactly has nothing to teach, and storing it would grow the alias
        // list forever with duplicates.
        var aliasesToLearn: [String: String] = [:]
        for match in matches where !match.wasExact && !match.headerText.isEmpty {
            aliasesToLearn[match.fieldKey] = match.headerText
        }

        return (records, diagnostics, aliasesToLearn)
    }

    private func value(
        for field: FieldSnapshot,
        in row: [RecognizedCell],
        matches: [ColumnMatcher.Match],
        template: TemplateSnapshot
    ) -> ExtractedValue {
        guard
            let match = matches.first(where: { $0.fieldKey == field.key }),
            row.indices.contains(match.columnIndex)
        else {
            return applyingDefault(field) ?? .unresolved(fieldKey: field.key)
        }

        let cell = row[match.columnIndex]
        guard !cell.text.isEmpty else {
            return applyingDefault(field) ?? .unresolved(fieldKey: field.key)
        }

        let normalized = normalizer.normalize(
            cell.text,
            as: field.type,
            using: .forField(field, in: template)
        )

        // Three independent doubts multiply: how well the column was identified, how cleanly
        // the cell was read, and whether the value parsed as its declared type. Any one of
        // them being shaky should be enough to ask the user to look.
        let confidence = match.score * cell.recognitionConfidence * normalized.confidenceMultiplier

        return ExtractedValue(
            fieldKey: field.key,
            rawText: cell.text,
            normalized: normalized.text,
            confidence: confidence,
            source: .deterministic,
            frame: cell.frame
        )
    }

    // MARK: Record mode

    /// Label-anchored reading: find the field's label on the page, then take the nearest text
    /// to its right, or failing that directly below it. This is how printed forms are laid
    /// out and it is reliable on them.
    private func recordModeRecord(
        page: RecognizedPage,
        template: TemplateSnapshot
    ) -> ExtractedRecord {
        ExtractedRecord(
            sourceRowIndex: nil,
            values: template.fields.map { field in
                guard let anchor = labelBlock(for: field, in: page) else {
                    return applyingDefault(field) ?? .unresolved(fieldKey: field.key)
                }
                guard let valueBlock = nearestValue(after: anchor.block, in: page) else {
                    return applyingDefault(field) ?? .unresolved(fieldKey: field.key)
                }

                let normalized = normalizer.normalize(
                    valueBlock.text,
                    as: field.type,
                    using: .forField(field, in: template)
                )

                return ExtractedValue(
                    fieldKey: field.key,
                    rawText: valueBlock.text,
                    normalized: normalized.text,
                    confidence: anchor.score * valueBlock.recognitionConfidence
                        * normalized.confidenceMultiplier,
                    source: .deterministic,
                    frame: valueBlock.frame
                )
            }
        )
    }

    private func labelBlock(
        for field: FieldSnapshot,
        in page: RecognizedPage
    ) -> (block: RecognizedBlock, score: Double)? {
        let aliases = field.aliases.isEmpty ? [field.label] : field.aliases

        let scored = page.blocks.map { block -> (RecognizedBlock, Double) in
            // A label often arrives with its colon attached — "Name:" — so score the leading
            // portion of the block as well as the whole thing.
            let whole = StringSimilarity.bestScore(for: block.text, among: aliases)
            let leading = StringSimilarity.bestScore(
                for: String(block.text.prefix(field.label.count + 1)), among: aliases
            )
            return (block, max(whole, leading))
        }

        guard
            let best = scored.max(by: { $0.1 < $1.1 }),
            best.1 >= ColumnMatcher.minimumScore
        else { return nil }

        return (best.0, best.1)
    }

    /// The block to the right on roughly the same line, else the nearest block below.
    private func nearestValue(
        after label: RecognizedBlock,
        in page: RecognizedPage
    ) -> RecognizedBlock? {
        let sameLineTolerance = label.frame.height

        let toTheRight = page.blocks
            .filter { candidate in
                candidate.frame.x > label.frame.maxX
                    && abs(candidate.frame.midY - label.frame.midY) < sameLineTolerance
            }
            .min { $0.frame.x < $1.frame.x }

        if let toTheRight { return toTheRight }

        return page.blocks
            .filter { $0.frame.y > label.frame.y + label.frame.height * 0.5 }
            .min { $0.frame.y < $1.frame.y }
    }

    // MARK: Shared

    /// A declared default stands in for a value that was not found — but it is marked as a
    /// default rather than dressed up as something read off the page.
    private func applyingDefault(_ field: FieldSnapshot) -> ExtractedValue? {
        guard let defaultValue = field.defaultValue, !defaultValue.isEmpty else { return nil }
        return ExtractedValue(
            fieldKey: field.key,
            rawText: "",
            normalized: defaultValue,
            confidence: ConfidenceThreshold.medium,
            source: .defaultValue,
            frame: nil
        )
    }
}
