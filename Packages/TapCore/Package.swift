// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TapCore", targets: ["TapCore"])
    ],
    targets: [
        .target(name: "TapCore"),
        .testTarget(name: "TapCoreTests", dependencies: ["TapCore"])
    ]
)
