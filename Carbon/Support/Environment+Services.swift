import CarbonCore
import SwiftUI

extension EnvironmentValues {
    /// Defaults to a set that reads nothing, never to fakes.
    ///
    /// `CarbonApp` injects `.live(container:)` at the root and every `#Preview` injects
    /// `.preview()` explicitly, so this default should never be reached. It matters anyway:
    /// a default made of fakes means a view that somehow missed the injection carries on
    /// looking like it works, showing invented values from a service set that read nothing.
    /// `.unconfigured` fails visibly instead, and it lives in `CarbonCore`, which is what
    /// keeps the fixtures package out of the app's production code entirely.
    @Entry var services: Services = .unconfigured
}
