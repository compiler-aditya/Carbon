import Foundation
import Testing

@testable import CarbonCore

@Suite("Timeout helper")
struct TimeoutTests {
    /// Records whether the wrapped operation noticed it was cancelled.
    private actor CancellationWitness {
        private(set) var wasCancelled = false
        func note() { wasCancelled = true }
    }

    private struct Boom: Error, Equatable {}

    @Test("An operation that finishes in time returns its value")
    func fastOperationSucceeds() async throws {
        let result = try await withTimeout(.seconds(5)) { 42 }
        #expect(result == 42)
    }

    @Test("An operation that overruns throws TimedOutError")
    func slowOperationTimesOut() async {
        await #expect(throws: TimedOutError(duration: .milliseconds(20))) {
            try await withTimeout(.milliseconds(20)) {
                try await Task.sleep(for: .seconds(30))
                return 0
            }
        }
    }

    @Test("The operation's own error propagates rather than being masked as a timeout")
    func operationErrorPropagates() async {
        await #expect(throws: Boom.self) {
            try await withTimeout(.seconds(5)) { throw Boom() }
        }
    }

    @Test("Losing the race actually cancels the operation")
    func losingOperationIsCancelled() async throws {
        let witness = CancellationWitness()

        try? await withTimeout(.milliseconds(20)) {
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                await witness.note()
                throw error
            }
        }

        // The cancellation is delivered as the group tears down, so give it a moment to land
        // rather than asserting on a race we would lose intermittently in CI.
        try await Task.sleep(for: .milliseconds(100))
        #expect(await witness.wasCancelled)
    }

    @Test("The deadline is carried on the error, so a caller can report which budget was missed")
    func errorCarriesDuration() async {
        do {
            try await withTimeout(.milliseconds(10)) {
                try await Task.sleep(for: .seconds(30))
            }
            Issue.record("expected a timeout")
        } catch let error as TimedOutError {
            #expect(error.duration == .milliseconds(10))
        } catch {
            Issue.record("expected TimedOutError, got \(error)")
        }
    }
}
