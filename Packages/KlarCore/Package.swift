// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KlarCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "KlarCore", targets: ["KlarCore"])
    ],
    targets: [
        .target(name: "KlarCore"),
        .testTarget(name: "KlarCoreTests", dependencies: ["KlarCore"])
    ]
)
