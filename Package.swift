// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Thea",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TheaCore",
            targets: ["TheaCore"]
        )
    ],
    dependencies: [
        // AI Provider SDKs
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.2.0"),

        // Security
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),

        // Markdown rendering
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),

        // Syntax highlighting
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "TheaCore",
            dependencies: [
                .product(name: "OpenAI", package: "OpenAI"),
                "KeychainAccess",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                "Highlightr"
            ],
            path: "Shared",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TheaCoreTests",
            dependencies: ["TheaCore"],
            path: "Tests"
        )
    ]
)
