// swift-tools-version: 6.0
// thea-audit - Security scanner for Thea application
// Part of AgentSec Strict Mode implementation

import PackageDescription

let package = Package(
    name: "thea-audit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "thea-audit", targets: ["thea-audit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "thea-audit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/thea-audit"
        ),
        .testTarget(
            name: "thea-auditTests",
            dependencies: ["thea-audit"],
            path: "Tests/thea-auditTests"
        )
    ]
)
