// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PatternSpaceSDK",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "PatternSpaceSDKCore",   targets: ["PatternSpaceSDKCore"]),
        .library(name: "PatternSpaceSDKClient", targets: ["PatternSpaceSDKClient"]),
        .library(name: "PatternSpaceSDKServer", targets: ["PatternSpaceSDKServer"]),
    ],
    targets: [
        .target(name: "PatternSpaceSDKCore"),
        .target(name: "PatternSpaceSDKClient", dependencies: ["PatternSpaceSDKCore"]),
        .target(name: "PatternSpaceSDKServer", dependencies: ["PatternSpaceSDKCore"]),
        .testTarget(name: "PatternSpaceSDKCoreTests",   dependencies: ["PatternSpaceSDKCore"],   path: "Tests/PatternSpaceSDKCoreTests"),
        .testTarget(name: "PatternSpaceSDKServerTests", dependencies: ["PatternSpaceSDKServer"], path: "Tests/PatternSpaceSDKServerTests"),
    ]
)
