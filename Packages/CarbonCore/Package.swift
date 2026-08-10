// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CarbonCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "CarbonCore", targets: ["CarbonCore"]),
        // Not linked by the app. The harness measures Carbon; it is not part of it.
        .executable(name: "CorpusHarness", targets: ["CorpusHarness"]),
    ],
    targets: [
        .target(
            name: "CarbonCore",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CorpusScoring",
            dependencies: ["CarbonCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "CorpusHarness",
            dependencies: ["CorpusScoring"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CarbonCoreTests",
            dependencies: ["CarbonCore", "CorpusScoring"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
