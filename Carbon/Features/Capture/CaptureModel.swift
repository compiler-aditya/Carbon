import CarbonCore
import CoreGraphics
import Foundation
import Observation

/// Drives capture → persist → recognise → extract → save.
///
/// One explicit state enum rather than scattered booleans, because this flow has five real
/// outcomes and `isLoading` + `hasError` + `showSheet` is how a screen becomes unreadable by
/// Friday.
@MainActor
@Observable
final class CaptureModel {
    enum Step: Equatable {
        case reading
        case matching
        case checking

        /// Specific labels, not a spinner. If the model pass makes "Matching fields" sit for
        /// a few seconds, the user can at least see what it is sitting on.
        var label: String {
            switch self {
            case .reading: String(localized: "Reading page…")
            case .matching: String(localized: "Matching fields…")
            case .checking: String(localized: "Checking values…")
            }
        }
    }

    enum State: Equatable {
        case idle
        case capturing
        case processing(step: Step, pageIndex: Int, total: Int)
        case review(recordIDs: [UUID])
        case failed(CarbonError)
    }

    private(set) var state: State = .idle

    /// Set when the meter says this scan would cross a free-tier limit. The paywall is
    /// presented from here rather than thrown, because a limit is not an error.
    var paywallReason: PaywallReason?

    /// Populated when a table-mode page crossed the limit mid-way: some rows were saved and
    /// the rest need Pro. Honest partial success beats an all-or-nothing refusal.
    private(set) var partialSave: (saved: Int, needsPro: Int)?

    private let services: Services
    private let store: CarbonStore
    private let template: TemplateSnapshot

    init(services: Services, store: CarbonStore, template: TemplateSnapshot) {
        self.services = services
        self.store = store
        self.template = template
    }

    /// Checks the camera permission and then the meter, both **before** the camera opens.
    ///
    /// Making someone watch the work happen and then refusing to save it is hostile, so the
    /// gates come first or not at all.
    func beginCapture(usingCamera: Bool = false) async {
        if usingCamera, let denial = CameraAuthorization.denial() {
            state = .failed(denial)
            return
        }

        let decision = await services.meter.canCreateRecords(
            count: 1, isPro: services.entitlements.isPro
        )
        if case .paywall(let reason) = decision {
            paywallReason = reason
            return
        }
        state = .capturing
    }

    func cancelCapture() {
        state = .idle
    }

    /// Raised by the screen for a failure it detected itself, before the pipeline was reached.
    func fail(_ error: CarbonError) {
        state = .failed(error)
    }

    /// Clears a failure so the screen underneath is usable again.
    ///
    /// Returning to `.idle` rather than holding the error means dismissing the sheet and
    /// tapping Scan works, instead of re-presenting the failure the user just read.
    func dismissFailure() {
        if case .failed = state { state = .idle }
    }

    /// Runs the pipeline over captured pages.
    func process(pages: [CGImage]) async {
        guard !pages.isEmpty else {
            state = .idle
            return
        }

        var allRecordIDs: [UUID] = []

        for (index, image) in pages.enumerated() {
            do {
                let ids = try await processPage(image, index: index, of: pages.count)
                allRecordIDs.append(contentsOf: ids)
            } catch let error as CarbonError {
                state = .failed(error)
                return
            } catch {
                state = .failed(.recognitionFailed(pageIndex: index))
                return
            }
        }

        state = .review(recordIDs: allRecordIDs)
    }

    private func processPage(_ image: CGImage, index: Int, of total: Int) async throws -> [UUID] {
        // One identity for this photograph, shared by every record it produces. A table page
        // yields many rows from one image, so the file cannot be keyed by a record.
        let captureID = UUID()

        // Persist before anything else. A crash during extraction must never cost someone a
        // photograph of a page they have already filed away.
        state = .processing(step: .reading, pageIndex: index, total: total)
        let pageRef = try await services.pageStore.persist(
            image, captureID: captureID, pageIndex: 0
        )

        let page = try await services.recognizer.recognize(image, pageID: captureID)

        state = .processing(step: .matching, pageIndex: index, total: total)
        let result = await services.extractor.extract(page: page, template: template)

        state = .processing(step: .checking, pageIndex: index, total: total)

        // Before the meter, deliberately. A page that read as nothing is a failure the user
        // needs told about; a page the meter trimmed to nothing is a paywall. Checking the
        // meter first would present the second when it is really the first.
        if let outcome = result.emptyOutcome(for: template) {
            throw outcome
        }

        let decision = await services.meter.canCreateRecords(
            count: result.records.count, isPro: services.entitlements.isPro
        )

        let allowed: [ExtractedRecord]
        switch decision {
        case .allowed:
            allowed = result.records
        case .partial(let count):
            allowed = Array(result.records.prefix(count))
            partialSave = (saved: count, needsPro: result.records.count - count)
            paywallReason = .recordLimit
        case .paywall(let reason):
            allowed = []
            paywallReason = reason
        }

        guard !allowed.isEmpty else { return [] }

        let trimmed = ExtractionResult(
            records: allowed,
            pageID: result.pageID,
            durationMs: result.durationMs,
            engineVersion: result.engineVersion,
            diagnostics: result.diagnostics,
            aliasesToLearn: result.aliasesToLearn
        )

        // Mapped rather than left to the generic catch, which would report a full disk as
        // "that page couldn't be read" and send the user off to retake a perfectly good photo.
        let ids: [UUID]
        do {
            ids = try await store.save(
                trimmed,
                templateID: template.id,
                pages: [pageRef],
                rawPageText: page.fullText
            )
        } catch {
            throw CarbonError.saveFailed(underlying: String(describing: error))
        }

        await services.meter.recordCreated(count: ids.count)
        return ids
    }
}
