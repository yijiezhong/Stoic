// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stoic",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StoicCore", targets: ["StoicCore"]),
        .executable(name: "Stoic", targets: ["Stoic"])
    ],
    targets: [
        .target(name: "StoicCore", path: "Sources/StoicCore", resources: [.process("Resources")]),
        .executableTarget(name: "Stoic", dependencies: ["StoicCore"], path: "Sources/Stoic"),
        .testTarget(name: "StoicCoreTests", dependencies: ["StoicCore"], path: "Tests/StoicCoreTests")
    ]
)
