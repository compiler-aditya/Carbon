import CarbonCore
import Foundation

/// Renders a report as the markdown table that goes straight into the README.
///
/// Shaped to match `docs/08-readme-template.md` exactly, so the accuracy section is pasted
/// rather than retyped. A number retyped by hand is a number that drifts from the run that
/// produced it.
public enum CorpusReportFormatter {
    public static func markdown(_ report: CorpusReport) -> String {
        let printed = report.pages.filter { !$0.isHandwritten }
        let written = report.pages.filter(\.isHandwritten)

        var lines: [String] = []

        // The disclaimer travels with the numbers on purpose. This output is meant to be pasted
        // straight into the README, so a run with no photographs behind it has to arrive
        // carrying the reason it is not an accuracy claim — otherwise the paste launders it
        // into one.
        let photographs = report.pages.filter { !$0.isRendered }
        if photographs.isEmpty, !report.pages.isEmpty {
            lines.append(
                """
                > **Not an accuracy measurement.** Every page scored here was drawn by this \
                repository rather than photographed, so there is no camera in the input — no \
                skew, no shadow, no paper, no lens. These numbers show the pipeline and the \
                harness running end to end. They say nothing about how Carbon reads a real page.
                """
            )
            lines.append("")
        }

        lines.append("Measured on \(composition(of: report)).")
        lines.append("")
        lines.append("| Metric | Printed forms | Handwritten |")
        lines.append("|---|---|---|")
        lines.append(
            row(
                "Records needing no correction",
                measure(report.recordsNeedingNoCorrection(handwritten: false), has: !printed.isEmpty),
                measure(report.recordsNeedingNoCorrection(handwritten: true), has: !written.isEmpty)
            )
        )
        lines.append(
            row(
                "Field-level precision",
                measure(report.fieldPrecision(handwritten: false), has: !printed.isEmpty),
                measure(report.fieldPrecision(handwritten: true), has: !written.isEmpty)
            )
        )
        lines.append(
            row(
                "Resolved by Tier 1 alone",
                measure(report.tier1Share(handwritten: false), has: !printed.isEmpty),
                measure(report.tier1Share(handwritten: true), has: !written.isEmpty)
            )
        )
        lines.append(
            row(
                "Rows found correctly",
                measure(report.rowCountAccuracy(handwritten: false), has: !printed.isEmpty),
                measure(report.rowCountAccuracy(handwritten: true), has: !written.isEmpty)
            )
        )
        lines.append(
            row(
                "Median latency per page",
                seconds(report.medianLatency(handwritten: false)),
                seconds(report.medianLatency(handwritten: true))
            )
        )
        lines.append(
            row(
                "p95 latency per page",
                seconds(report.p95Latency(handwritten: false)),
                seconds(report.p95Latency(handwritten: true))
            )
        )

        let byType = report.precisionByType()
        if !byType.isEmpty {
            lines.append("")
            lines.append("**By field type**")
            lines.append("")
            lines.append("| Type | Precision |")
            lines.append("|---|---|")
            for (type, precision) in byType.sorted(by: { $0.value < $1.value }) {
                lines.append("| \(type.rawValue) | \(percent(precision)) |")
            }
        }

        let missed = report.mostMissedFields()
        if !missed.isEmpty {
            lines.append("")
            lines.append("**Where it fails**")
            lines.append("")
            for miss in missed {
                lines.append(
                    "- `\(miss.fieldKey)` — wrong \(percent(miss.missRate)) of the time "
                        + "(\(miss.count) values)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    /// The short form printed to the terminal after a run.
    public static func summary(_ report: CorpusReport) -> String {
        """
        \(report.pages.count) pages, \
        \(report.pages.flatMap(\.outcomesByRecord).count) records, \
        \(report.pages.flatMap(\.outcomes).count) values
        Records needing no correction: \(percent(report.recordsNeedingNoCorrection()))
        Field precision:               \(percent(report.fieldPrecision()))
        Resolved by Tier 1 alone:      \(percent(report.tier1Share()))
        Left unresolved:               \(percent(report.unresolvedShare()))
        Median / p95 latency:          \(seconds(report.medianLatency())) / \
        \(seconds(report.p95Latency()))
        """
    }

    /// Says what was actually scored, in the words the thing deserves. A page that was never
    /// photographed is never called a photograph.
    private static func composition(of report: CorpusReport) -> String {
        let rendered = report.pages.filter(\.isRendered).count
        let photographed = report.pages.count - rendered
        let written = report.pages.filter(\.isHandwritten).count
        let printed = report.pages.count - written

        var parts: [String] = []
        if photographed > 0 {
            parts.append("\(photographed) photograph\(photographed == 1 ? "" : "s")")
        }
        if rendered > 0 {
            parts.append("\(rendered) rendered page\(rendered == 1 ? "" : "s")")
        }
        if parts.isEmpty { return "**nothing**" }

        return "**\(parts.joined(separator: " and "))** — \(printed) printed and \(written) handwritten"
    }

    private static func row(_ label: String, _ printed: String, _ handwritten: String) -> String {
        "| \(label) | \(printed) | \(handwritten) |"
    }

    /// An em dash for "not measured", never 0%.
    ///
    /// A corpus with no handwritten pages yet would otherwise publish a column of zeroes,
    /// which reads as catastrophic failure rather than absent data — and this table goes
    /// into the README exactly as printed.
    static func measure(_ value: @autoclosure () -> Double, has data: Bool) -> String {
        data ? percent(value()) : "—"
    }

    /// One decimal place, and never rounded up.
    ///
    /// Understating is the whole posture of this table: the README's argument is that the
    /// numbers are honest, and a value rounded in our favour would undercut it for a tenth
    /// of a percent.
    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let truncated = (value * 1000).rounded(.down) / 10
        return "\(truncated)%"
    }

    static func seconds(_ duration: Duration) -> String {
        guard duration > .zero else { return "—" }
        let value = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
        return String(format: "%.2f s", value)
    }
}
