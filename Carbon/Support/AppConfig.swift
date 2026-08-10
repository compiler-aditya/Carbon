import Foundation

/// Typed access to build configuration.
///
/// The key arrives via `Config/Base.xcconfig` → `Info.plist` → here. There is no code path in
/// which a missing or placeholder key stops the app: configuration failing means the user is
/// treated as free tier and everything except purchasing works.
enum AppConfig {
    static var revenueCatAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
    }

    /// True when nobody has supplied a key — the state a fresh clone is in.
    ///
    /// Used to skip configuring the SDK entirely rather than handing it a string it will
    /// reject. Purchases are unavailable; nothing else changes.
    static var isUsingPlaceholderKey: Bool {
        let key = revenueCatAPIKey
        return key.isEmpty || key == "test_REPLACE_ME" || key.hasPrefix("$(")
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
