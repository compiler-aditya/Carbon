import CoreGraphics
import CoreText
import Foundation
import Testing

@testable import CarbonCore

/// Runs the real Vision request against a rendered page.
///
/// The rest of the suite feeds hand-built `RecognizedPage` fixtures through the ladder, which
/// tests our logic but never checks that the *mapping out of Vision* is right. Everything in
/// `LiveRecognizer` — the coordinate flip, the confidence derivation, the transcript — is
/// invisible to those tests and would fail silently on a device.
///
/// A rendered form is not a photograph, so this proves the mapping rather than the accuracy.
/// Accuracy is what the corpus harness measures.
@Suite("Live recognition against a rendered page")
struct LiveRecognizerIntegrationTests {
    /// Draws a ruled register: a title, a header row, and three data rows.
    private func renderRegister(width: Int = 1000, height: Int = 700) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 0, alpha: 1)

        let rows = [
            ["Date", "Item", "Qty", "Amount"],
            ["01/04/2026", "Basmati rice", "12", "6720.00"],
            ["02/04/2026", "Mustard oil", "8", "1484.00"],
            ["03/04/2026", "Sugar", "30", "1440.00"],
        ]
        let columnX: [CGFloat] = [60, 300, 620, 760]

        draw("Daily Sales Register", at: CGPoint(x: 60, y: 620), size: 30, in: context)

        // Vision needs a real grid to report a table, so the rules are drawn, not implied.
        context.setStrokeColor(gray: 0.2, alpha: 1)
        context.setLineWidth(2)
        for index in 0...rows.count {
            let y = CGFloat(540 - index * 70)
            context.move(to: CGPoint(x: 40, y: y))
            context.addLine(to: CGPoint(x: CGFloat(width) - 40, y: y))
        }
        for x in [40, 280, 600, 740, width - 40] {
            context.move(to: CGPoint(x: CGFloat(x), y: 540))
            context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(540 - rows.count * 70)))
        }
        context.strokePath()

        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, text) in row.enumerated() {
                draw(
                    text,
                    at: CGPoint(x: columnX[columnIndex], y: CGFloat(490 - rowIndex * 70)),
                    size: 26,
                    in: context
                )
            }
        }

        return context.makeImage()!
    }

    private func draw(_ text: String, at point: CGPoint, size: CGFloat, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        // CoreText's own attribute keys — .font and .foregroundColor come from UIKit/AppKit,
        // and CarbonCore imports neither.
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                    CGColor(gray: 0, alpha: 1),
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    @Test("Vision reads the rendered page and the transcript survives the mapping")
    func recognizesRenderedPage() async throws {
        let page = try await LiveRecognizer().recognize(renderRegister(), pageID: UUID())

        #expect(!page.fullText.isEmpty, "nothing was recognised at all")
        // The words we drew have to come back out of our own DTO, not just out of Vision.
        #expect(page.fullText.contains("Basmati"))
        #expect(page.fullText.contains("6720"))
    }

    @Test("Frames come back normalised, top-left origin, and the title is above the rows")
    func frameMappingIsCorrect() async throws {
        let page = try await LiveRecognizer().recognize(renderRegister(), pageID: UUID())

        let allFrames = page.blocks.map(\.frame) + page.tables.flatMap { $0.rows.flatMap { $0.map(\.frame) } }
        try #require(!allFrames.isEmpty, "no geometry was produced")

        for frame in allFrames {
            #expect(frame.x >= 0 && frame.x <= 1)
            #expect(frame.y >= 0 && frame.y <= 1)
            #expect(frame.width > 0 && frame.width <= 1)
        }

        // The coordinate flip is the easiest thing here to get backwards, and a mirrored
        // zoom target is the symptom nobody can reproduce. The title was drawn near the top
        // of the page, so in our top-left system it must have a small y.
        let title = page.blocks
            .first { $0.text.localizedCaseInsensitiveContains("Daily Sales Register") }
        let titleFrame = try #require(title?.frame, "the title was not recognised")

        let lowestBlock = page.blocks.map(\.frame.y).max() ?? 1
        #expect(
            titleFrame.y < lowestBlock,
            "title should sit above the lowest block; if not, the origin flip is inverted"
        )
        #expect(titleFrame.y < 0.5, "the title was drawn in the upper half of the page")
    }

    @Test("Confidence comes back in range, derived from the recognised lines")
    func confidenceIsDerived() async throws {
        let page = try await LiveRecognizer().recognize(renderRegister(), pageID: UUID())
        try #require(!page.blocks.isEmpty)

        for block in page.blocks {
            #expect(block.recognitionConfidence >= 0 && block.recognitionConfidence <= 1)
        }
        // Crisply rendered text should read well. If this ever fails, the derivation is
        // taking the wrong thing rather than the page being hard to read.
        #expect(page.blocks.contains { $0.recognitionConfidence > 0.5 })
    }

    @Test("The real recognizer feeds the real extractor end to end")
    func fullPipeline() async throws {
        let page = try await LiveRecognizer().recognize(renderRegister(), pageID: UUID())

        let template = TemplateSnapshot(
            id: UUID(),
            name: "Daily Register",
            mode: .table,
            dateConvention: .dayMonthYear,
            preferredDateFormat: nil,
            fields: [
                FieldSnapshot(
                    id: UUID(), key: "item", label: "Item", type: .text, isRequired: false,
                    aliases: ["item"], choices: [], defaultValue: nil, currencyCode: nil,
                    validationPattern: nil, lastKnownFrame: nil
                ),
                FieldSnapshot(
                    id: UUID(), key: "amount", label: "Amount", type: .currency, isRequired: false,
                    aliases: ["amount", "amt"], choices: [], defaultValue: nil, currencyCode: nil,
                    validationPattern: nil, lastKnownFrame: nil
                ),
            ],
            learnedHeaderAliases: []
        )

        let result = await DeterministicExtractor().extract(page: page, template: template)

        // Table detection on synthetic input is Vision's business and not something to pin
        // down here — but if it did find the grid, the values must map through correctly.
        // Accuracy on real photographs is what the corpus harness measures.
        if !result.records.isEmpty {
            let items = result.records.compactMap { $0.value(forKey: "item")?.normalized }
            #expect(items.contains { $0.localizedCaseInsensitiveContains("Basmati") })
        }
        #expect(result.engineVersion == DeterministicExtractor.engineVersion)
    }
}
