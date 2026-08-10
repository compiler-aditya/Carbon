import CarbonCore
import CarbonTestFixtures
import SwiftUI

extension EnvironmentValues {
    /// Defaults to fakes so that every `#Preview` works with no injection and no camera.
    /// `CarbonApp` replaces this with `.live()` at the root for the running app.
    @Entry var services: Services = .preview()
}
