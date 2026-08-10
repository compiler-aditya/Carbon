import Foundation

/// Thrown when an operation outran its deadline.
///
/// Deliberately not a `CarbonError`. This helper wraps Vision work as well as model work, and
/// the caller decides what a timeout means in its own context — the extraction ladder turns it
/// into `.modelTimedOut` and falls through to Tier 3, which is not a failure at all.
public struct TimedOutError: Error, Equatable, Sendable {
    public let duration: Duration

    public init(duration: Duration) {
        self.duration = duration
    }
}

/// Runs `operation`, giving up after `duration`.
///
/// The losing side is always cancelled: if the deadline wins, the operation is cancelled
/// rather than left running to finish into nothing, which on a model session means the work
/// actually stops instead of quietly holding the session for another few seconds.
///
/// Cooperative cancellation, so `operation` only stops at a suspension point. Every framework
/// call we wrap has one.
public func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimedOutError(duration: duration)
        }

        // The first task to finish decides the outcome, win or throw. Leaving the group
        // cancels whatever is left.
        defer { group.cancelAll() }
        guard let first = try await group.next() else {
            throw TimedOutError(duration: duration)
        }
        return first
    }
}
