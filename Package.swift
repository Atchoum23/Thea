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
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),

        // MLX Swift for native on-device LLM inference (macOS 26+ best practices)
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main")
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
                // Swift 6 has strict concurrency enabled by default
            ]
        ),
        .testTarget(
            name: "TheaCoreTests",
            dependencies: ["TheaCore"],
            path: "Tests"
        )
    ]
)
