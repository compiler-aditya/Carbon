import CarbonCore
import Foundation

/// Creates a starter template and runs the real pipeline over its bundled photograph.
///
/// Nothing here is faked. The only thing supplied is the image — recognition, extraction,
/// normalization and the write are exactly the ones a scan goes through, so what a first-run
/// user sees is what the app actually does, including whatever it gets wrong.
@MainActor
enum SampleFormInstaller {
    struct Installed {
        let templateID: UUID
        let recordIDs: [UUID]
    }

    static func install(
        _ sample: SampleFormLibrary.Sample,
        services: Services,
        store: CarbonStore
    ) async throws -> Installed {
        let templateID = try await store.createTemplate(
            name: sample.name,
            subtitle: sample.subtitle,
            mode: sample.mode,
            symbolName: sample.symbolName,
            fields: sample.fields
        )
        await services.meter.templateCreated()

        guard
            let image = SampleFormLibrary.image(for: sample),
            let template = try await store.templateSnapshot(id: templateID)
        else {
            // The template is still worth having even with no picture to feed it.
            return Installed(templateID: templateID, recordIDs: [])
        }

        let captureID = UUID()
        let pageRef = try await services.pageStore.persist(
            image, captureID: captureID, pageIndex: 0
        )
        let page = try await services.recognizer.recognize(image, pageID: captureID)
        let result = await services.extractor.extract(page: page, template: template)

        let ids = try await store.save(
            result,
            templateID: templateID,
            pages: [pageRef],
            rawPageText: page.fullText
        )
        await services.meter.recordCreated(count: ids.count)

        return Installed(templateID: templateID, recordIDs: ids)
    }
}
