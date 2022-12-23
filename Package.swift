// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Loop",
    platforms: [
        .macOS(.v10_13), .iOS(.v11), .tvOS(.v11), .watchOS(.v4)
    ],
    products: [
        .library(name: "Loop", targets: ["Loop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.0"),
    ],
    targets: [
        .target(name: "Loop", dependencies: ["ReactiveSwift"], path: "Loop"),
        .testTarget(name: "LoopTests", dependencies: ["Loop", "ReactiveSwift", "Nimble"], path: "LoopTests"),
    ],
    swiftLanguageVersions: [.v5]
)
