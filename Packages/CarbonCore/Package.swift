// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CarbonCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "CarbonCore", targets: ["CarbonCore"])],
    targets: [
        .target(
            name: "CarbonCore",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "CarbonCoreTests", dependencies: ["CarbonCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
