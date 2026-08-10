// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CarbonTestFixtures",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "CarbonTestFixtures", targets: ["CarbonTestFixtures"])],
    dependencies: [.package(path: "../CarbonCore")],
    targets: [
        .target(
            name: "CarbonTestFixtures",
            dependencies: [.product(name: "CarbonCore", package: "CarbonCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
