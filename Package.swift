// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OTooliOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OTooliOS",
            targets: ["OTooliOS"]),
        .executable(
            name: "otool-cli",
            targets: ["OToolCLI"])
    ],
    targets: [
        .target(
            name: "OTooliOS",
            dependencies: [],
            path: "Sources/OTooliOS"),
        .executableTarget(
            name: "OToolCLI",
            dependencies: ["OTooliOS"],
            path: "Sources/OToolCLI"),
        .testTarget(
            name: "OTooliOSTests",
            dependencies: ["OTooliOS"],
            path: "Tests/OTooliOSTests")
    ]
)
