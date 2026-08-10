import Foundation

/// The full Tier 1 → 2 → 3 ladder.
///
/// Tier 1 always runs and carries the common case. Tier 2 is offered only the leftovers, and
/// only in record mode. Tier 3 is whatever is still missing, which is a normal outcome and
/// renders as a field waiting to be filled in.
///
/// **Why Tier 2 skips table mode.** The budget is one model session per page. A register with
/// fourteen rows would need either fourteen sessions — far past the page budget and past any
/// reasonable wait — or one session asked to reconstruct a grid from a flat transcript, which
/// is exactly the task a text-only model is worst at and the task Vision's table detection
/// already does properly. Tier 1's column matching is the right tool for a grid, and where it
/// cannot match a column the honest answer is to ask the user, not to guess a whole column.
/// This is recorded in the diagnostics rather than left to be discovered.
///
/// Never throws. Every failure inside — unavailable, timed out, refused — falls through to
/// Tier 3, because a page that produced something is always better than an error dialog.
public struct LadderExtractor: StructuredExtracting {
    public static let engineVersion = "vision-doc-1|tier1-1|fm-text-1|norm-1"

    private let deterministic: DeterministicExtractor
    private let resolver: (any ModelFieldResolving)?
    private let normalizer: any Normalizing

    public init(
        resolver: (any ModelFieldResolving)? = nil,
        normalizer: any Normalizing = StandardNormalizer()
    ) {
        self.deterministic = DeterministicExtractor(normalizer: normalizer)
        self.resolver = resolver
        self.normalizer = normalizer
    }

    public func extract(page: RecognizedPage, template: TemplateSnapshot) async -> ExtractionResult {
        let started = ContinuousClock.now
        let tier1 = await deterministic.extract(page: page, template: template)

        guard let resolver, template.mode == .record, let record = tier1.records.first else {
            return relabelled(tier1, diagnostics: skipDiagnostics(tier1, template: template))
        }

        let needing = fieldsNeedingHelp(in: record, template: template)
        guard !needing.isEmpty else {
            return relabelled(tier1, diagnostics: tier1.diagnostics + ["tier 2 not needed"])
        }

        var diagnostics = tier1.diagnostics
        var resolved: [String: String] = [:]

        do {
            resolved = try await resolver.resolve(
                fields: needing, pageText: page.fullText, template: template
            )
            diagnostics.append("tier 2 resolved \(resolved.count) of \(needing.count) fields")
        } catch let error as CarbonError {
            // Not surfaced to the user. The ladder has an answer; this is why it is the one
            // it is.
            diagnostics.append("tier 2 skipped: \(error)")
        } catch {
            diagnostics.append("tier 2 failed")
        }

        let merged = merge(record, resolved: resolved, template: template)
        let elapsed = started.duration(to: .now)

        return ExtractionResult(
            records: [merged],
            pageID: page.pageID,
            durationMs: Int(elapsed.components.seconds * 1000)
                + Int(elapsed.components.attoseconds / 1_000_000_000_000_000),
            engineVersion: Self.engineVersion,
            diagnostics: diagnostics
        )
    }

    /// Fields Tier 1 left empty or was unsure about.
    ///
    /// A value already read cleanly is never re-asked: the model would sometimes disagree
    /// with a correctly matched column, and trading a solid reading for a plausible-sounding
    /// one is a downgrade even when it happens to be right.
    private func fieldsNeedingHelp(
        in record: ExtractedRecord,
        template: TemplateSnapshot
    ) -> [FieldSnapshot] {
        template.fields.filter { field in
            guard let value = record.value(forKey: field.key) else { return true }
            return value.source == .unresolved || value.band == .needsReview
        }
    }

    private func merge(
        _ record: ExtractedRecord,
        resolved: [String: String],
        template: TemplateSnapshot
    ) -> ExtractedRecord {
        ExtractedRecord(
            sourceRowIndex: record.sourceRowIndex,
            values: template.fields.map { field in
                let existing = record.value(forKey: field.key)

                guard let raw = resolved[field.key] else {
                    return existing ?? .unresolved(fieldKey: field.key)
                }

                // Tier 1 keeps anything it read confidently; Tier 2 only fills gaps.
                if let existing, existing.source != .unresolved, existing.band != .needsReview {
                    return existing
                }

                let normalized = normalizer.normalize(
                    raw, as: field.type, using: .forField(field, in: template)
                )
                return ExtractedValue(
                    fieldKey: field.key,
                    rawText: raw,
                    normalized: normalized.text,
                    // Capped below the deterministic ceiling, so a model value never draws a
                    // solid rule however sure the model sounded.
                    confidence: ModelConfidence.ceiling * normalized.confidenceMultiplier,
                    source: .model,
                    // The model works from a flat transcript and cannot say where on the page
                    // a value sat, so there is nothing to zoom to. Claiming a frame here
                    // would point the review screen at the wrong place.
                    frame: nil
                )
            }
        )
    }

    private func skipDiagnostics(
        _ result: ExtractionResult,
        template: TemplateSnapshot
    ) -> [String] {
        guard resolver != nil else { return result.diagnostics + ["tier 2 unavailable"] }
        if template.mode == .table {
            return result.diagnostics + ["tier 2 skipped: table mode is resolved by column matching"]
        }
        return result.diagnostics
    }

    /// Re-stamps the engine version so a record says which ladder produced it, even when only
    /// Tier 1 ran. The corpus harness compares runs on exactly this.
    private func relabelled(_ result: ExtractionResult, diagnostics: [String]) -> ExtractionResult {
        ExtractionResult(
            records: result.records,
            pageID: result.pageID,
            durationMs: result.durationMs,
            engineVersion: Self.engineVersion,
            diagnostics: diagnostics
        )
    }
}
