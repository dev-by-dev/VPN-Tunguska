// swift-tools-version: 6.0
import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .path
let libboxFrameworkDirectory = "\(packageRoot)/Vendor/Libbox.xcframework/macos-arm64_x86_64"

let package = Package(
    name: "TunguskaCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "TunguskaCore", targets: ["TunguskaCore"]),
        .executable(name: "Tunguska", targets: ["Tunguska"]),
    ],
    targets: [
        .target(
            name: "TunguskaCore",
            path: "Sources/TunguskaCore"
        ),
        .testTarget(
            name: "TunguskaCoreTests",
            dependencies: ["TunguskaCore"],
            path: "Tests/TunguskaCoreTests"
        ),
        .executableTarget(
            name: "TunguskaCoreCheck",
            dependencies: ["TunguskaCore"],
            path: "Sources/TunguskaCoreCheck"
        ),
        .executableTarget(
            name: "Tunguska",
            dependencies: ["TunguskaCore"],
            path: "Sources/Tunguska"
        ),
        .executableTarget(
            name: "TunguskaHelper",
            dependencies: ["TunguskaCore"],
            path: "Sources/TunguskaHelper"
        ),
        .target(
            name: "TunguskaTunnel",
            dependencies: ["TunguskaCore"],
            path: "Sources/TunguskaTunnel",
            swiftSettings: [
                .unsafeFlags(["-F", libboxFrameworkDirectory]),
            ],
            linkerSettings: [
                .unsafeFlags(["-F", libboxFrameworkDirectory]),
                .linkedFramework("Libbox"),
                .linkedFramework("AppKit"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreText"),
                .linkedLibrary("bsm"),
                .linkedLibrary("resolv"),
            ]
        ),
    ]
)
