import CarbonCore
import CoreGraphics
import Foundation

/// Returns a canned recognised page, ignoring the image entirely.
///
/// Deterministic by design: the extraction tests and every preview need the same page every
/// run, and recognition quality is measured by the corpus harness rather than by unit tests.
public actor FakeRecognizer: Recognizing {
    private let page: RecognizedPage
    private let delay: Duration
    private let failureToThrow: (any Error)?

    public init(
        page: RecognizedPage = SampleRecognizedPages.dailyRegister,
        delay: Duration = .zero,
        failureToThrow: (any Error)? = nil
    ) {
        self.page = page
        self.delay = delay
        self.failureToThrow = failureToThrow
    }

    /// A recognizer that never returns, for exercising the timeout path.
    public static var hanging: FakeRecognizer {
        FakeRecognizer(delay: .seconds(3600))
    }

    public func recognize(_ image: CGImage, pageID: UUID) async throws -> RecognizedPage {
        if delay > .zero { try await Task.sleep(for: delay) }
        if let failureToThrow { throw failureToThrow }
        return page
    }
}
