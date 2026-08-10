import CarbonCore
import CoreGraphics
import Foundation
import ImageIO

/// Runs the real pipeline over a corpus directory and scores it against hand-typed truth.
public struct CorpusRunner: Sendable {
    private let recognizer: any Recognizing
    private let extractor: any StructuredExtracting

    public init(
        recognizer: any Recognizing = LiveRecognizer(),
        extractor: any StructuredExtracting = LadderExtractor(resolver: FoundationModelResolver())
    ) {
        self.recognizer = recognizer
        self.extractor = extractor
    }

    public enum RunError: Error, CustomStringConvertible {
        case missingManifest(URL)
        case noImages(URL)

        public var description: String {
            switch self {
            case .missingManifest(let url):
                "No manifest.json in \(url.path()). See docs/07-build-plan.md §5."
            case .noImages(let url):
                "No .jpg or .png images in \(url.path())."
            }
        }
    }

    public func run(
        directory: URL,
        onProgress: @Sendable (String) -> Void = { _ in }
    ) async throws -> CorpusReport {
        let manifestURL = directory.appending(path: "manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw RunError.missingManifest(directory)
        }
        let manifest = try JSONDecoder().decode(CorpusManifest.self, from: manifestData)

        let images = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !images.isEmpty else { throw RunError.noImages(directory) }

        var pages: [PageResult] = []
        for imageURL in images {
            guard let page = try await score(imageURL: imageURL, manifest: manifest) else {
                // A photograph with no ground truth beside it is a collection mistake, not a
                // failure of Carbon's. Skipping it loudly beats scoring against nothing.
                onProgress("skipped \(imageURL.lastPathComponent) — no matching .json")
                continue
            }
            onProgress(
                "\(page.imageName): \(page.outcomes.count(where: \.isCorrect))"
                    + "/\(page.outcomes.count) values"
            )
            pages.append(page)
        }

        return CorpusReport(pages: pages)
    }

    private func score(imageURL: URL, manifest: CorpusManifest) async throws -> PageResult? {
        let truthURL = imageURL.deletingPathExtension().appendingPathExtension("json")
        guard
            let truthData = try? Data(contentsOf: truthURL),
            let truth = try? JSONDecoder().decode(GroundTruth.self, from: truthData),
            let corpusTemplate = manifest.template(forType: truth.formType),
            let image = loadImage(at: imageURL)
        else { return nil }

        let template = corpusTemplate.snapshot()

        let started = ContinuousClock.now
        let recognized = try await recognizer.recognize(image, pageID: UUID())
        let result = await extractor.extract(page: recognized, template: template)
        let latency = started.duration(to: .now)

        return PageResult(
            imageName: imageURL.lastPathComponent,
            isHandwritten: truth.isHandwritten ?? false,
            expectedRecordCount: truth.records.count,
            actualRecordCount: result.records.count,
            outcomesByRecord: Self.compare(
                expected: truth.records, actual: result.records, template: template
            ),
            latency: latency
        )
    }

    /// Aligns extracted records against typed truth by position.
    ///
    /// Row order is the page's order, so index alignment is the right comparison. When Carbon
    /// finds fewer rows than exist, the missing ones are still scored — as unresolved values
    /// against the expected ones, because a row that was never found is a row the user has to
    /// type, and pretending it does not exist would flatter the number.
    static func compare(
        expected: [[String: String]],
        actual: [ExtractedRecord],
        template: TemplateSnapshot
    ) -> [[FieldOutcome]] {
        expected.enumerated().map { index, expectedRecord in
            let actualRecord = index < actual.count ? actual[index] : nil

            return template.fields.compactMap { field -> FieldOutcome? in
                // A field the collector did not type has no truth to score against.
                guard let expectedValue = expectedRecord[field.key] else { return nil }
                let value = actualRecord?.value(forKey: field.key)

                return FieldOutcome(
                    fieldKey: field.key,
                    type: field.type,
                    expected: expectedValue,
                    actual: value?.normalized ?? "",
                    source: value?.source ?? .unresolved
                )
            }
        }
    }

    private func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        // Corpus photographs come off real phones, so they carry EXIF rotation like any other.
        return ImageOrientationCorrection.upright(
            image, orientation: ImageOrientationCorrection.orientation(ofImageAt: source)
        )
    }
}
