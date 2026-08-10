import CoreGraphics
import DataDetection
import Foundation
import Vision

/// Reads page structure with Vision's `RecognizeDocumentsRequest`, then converts the result
/// into our own value types so that nothing downstream imports Vision.
///
/// An `actor` because Vision requests are expensive and there is no benefit to running many
/// at once on one device — pages are recognised one at a time, in order.
public actor LiveRecognizer: Recognizing {
    /// Recognition is bounded. A page that takes longer than this is a page the user is
    /// waiting on, and the ladder has a perfectly good answer without it.
    private let timeout: Duration

    public init(timeout: Duration = .seconds(10)) {
        self.timeout = timeout
    }

    public func recognize(_ image: CGImage, pageID: UUID) async throws -> RecognizedPage {
        let observations: [DocumentObservation]
        do {
            observations = try await withTimeout(timeout) {
                var request = RecognizeDocumentsRequest()

                // Language correction is off on purpose. It improves prose and actively
                // damages form data: an invoice number "INV0O41" gets "corrected" into a
                // word, and a corrected identifier no longer matches the customer's own
                // records. Carbon would rather report exactly what is on the page and let
                // the confidence rule flag it.
                request.textRecognitionOptions.useLanguageCorrection = false

                return try await request.perform(on: image)
            }
        } catch is TimedOutError {
            throw CarbonError.recognitionFailed(pageIndex: 0)
        }

        guard let document = observations.first?.document else {
            // Not a thrown error: a page with nothing legible on it is a real outcome, and
            // extraction turns it into fields waiting to be filled in rather than a dialog.
            return RecognizedPage(
                pageID: pageID, blocks: [], tables: [], detectedData: [], fullText: ""
            )
        }

        return RecognizedPage(
            pageID: pageID,
            blocks: Self.blocks(in: document),
            tables: document.tables.map(Self.table),
            detectedData: Self.detectedData(in: document),
            fullText: document.text.transcript
        )
    }

    /// Paragraphs, with their frames. Record-mode extraction is label-anchored, so it needs
    /// where things are and not only what they say.
    private static func blocks(in container: DocumentObservation.Container)
        -> [RecognizedBlock]
    {
        container.paragraphs.map { paragraph in
            RecognizedBlock(
                text: paragraph.transcript,
                frame: VisionGeometry.rect(from: paragraph.boundingRegion),
                recognitionConfidence: confidence(of: paragraph)
            )
        }
    }

    private static func table(_ table: DocumentObservation.Container.Table) -> RecognizedTable {
        let rows = table.rows.map { row in
            row.map { cell in
                RecognizedCell(
                    text: cell.content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines),
                    frame: VisionGeometry.rect(from: cell.content.boundingRegion),
                    rowRange: cell.rowRange,
                    columnRange: cell.columnRange,
                    recognitionConfidence: confidence(of: cell.content.text)
                )
            }
        }

        return RecognizedTable(
            frame: VisionGeometry.rect(from: table.boundingRegion),
            rows: rows,
            headerRowIndex: HeaderRowDetector.index(in: rows)
        )
    }

    private static func detectedData(in container: DocumentObservation.Container)
        -> [DetectedDatum]
    {
        let transcript = container.text.transcript
        return container.text.detectedData.compactMap { match in
            guard
                let kind = kind(of: match.match),
                let range = match.match.range
            else { return nil }

            return DetectedDatum(
                kind: kind,
                text: String(transcript[range]),
                frame: VisionGeometry.rect(from: match.boundingRegion)
            )
        }
    }

    /// Maps the detector's vocabulary onto ours.
    ///
    /// Note `calendarEvent` becoming `.date`: the detector has no bare date case, and what it
    /// calls a calendar event is what a register calls the date column. Kinds we have no use
    /// for — flight numbers, tracking numbers — are dropped rather than carried around.
    private static func kind(of match: DataDetector.Match) -> DetectedDatum.Kind? {
        switch match.details {
        case .calendarEvent: .date
        case .phoneNumber: .phoneNumber
        case .emailAddress: .emailAddress
        case .link: .url
        case .postalAddress: .postalAddress
        default: nil
        }
    }

    /// A block of text is only as trustworthy as its worst line.
    ///
    /// Vision reports confidence per recognised line, and a cell or paragraph has no score of
    /// its own. Taking the minimum rather than the mean is deliberate: one badly-read digit
    /// in an otherwise clean amount is exactly the case the review screen exists for, and an
    /// average would hide it.
    private static func confidence(of text: DocumentObservation.Container.Text) -> Double {
        let scores = text.lines.map { Double($0.confidence) }
        return scores.min() ?? 0
    }
}
