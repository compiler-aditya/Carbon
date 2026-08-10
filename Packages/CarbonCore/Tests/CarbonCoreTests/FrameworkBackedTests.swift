import Foundation
import Testing

/// Whether tests that drive Vision or FoundationModels should run.
///
/// These exercise real system frameworks against real model assets. That is genuinely
/// valuable on a developer's machine — it is how the mapping out of Vision gets checked at
/// all — and it is the wrong thing to run on a hosted CI runner, where the frameworks are
/// present but the assets and hardware behind them are not, and where they have segfaulted
/// the whole test process rather than failing an assertion.
///
/// `03-architecture.md` §7 already says Vision itself and the model's output quality are not
/// unit-test material; the corpus harness is what measures those. So CI runs the hermetic
/// suite and a developer gets the full one for free.
///
/// Set `CARBON_FRAMEWORK_TESTS=1` to force them on anywhere.
enum FrameworkBackedTests {
    static var areEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["CARBON_FRAMEWORK_TESTS"] == "1" { return true }
        return environment["CI"] == nil
    }
}
