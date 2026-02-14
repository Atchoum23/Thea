// swift-tools-version: 6.0
import PackageDescription

// MARK: - Package Configuration
//
// Following 2025/2026 modularization best practices:
// 1. Start with low-dependency modules first (Models, Interfaces)
// 2. Use Interface/Implementation pattern for decoupling
// 3. Layer-based organization (Foundation → Interfaces → Services)
//
// TheaFoundation contains:
// - TheaModels: Pure data models (Conversation, Message, Project)
// - TheaInterfaces: Protocol definitions for services
// - TheaServices: Mock implementations for testing (no SwiftData dependency)
//
// This achieves the FAST TEST goal:
// - `swift test` runs in <1 second (vs 25+ seconds with app host)
// - No app host required
// - Pure logic testing with mock services

let package = Package(
    name: "Thea",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Foundation layer: Models + Interfaces + Services
        .library(
            name: "TheaFoundation",
            targets: ["TheaModels", "TheaInterfaces", "TheaServices"]
        ),
        // Individual modules (for granular imports)
        .library(name: "TheaModels", targets: ["TheaModels"]),
        .library(name: "TheaInterfaces", targets: ["TheaInterfaces"]),
        .library(name: "TheaServices", targets: ["TheaServices"])
    ],
    dependencies: [
        // No external dependencies for foundation layer - pure Swift only
    ],
    targets: [
        // LAYER 1: Pure data models - no dependencies
        .target(
            name: "TheaModels",
            dependencies: [],
            path: "Shared/Core/Models",
            swiftSettings: [
                .define("THEA_MODELS_ONLY")
            ]
        ),

        // LAYER 2: Service interfaces/protocols - depends on Models
        .target(
            name: "TheaInterfaces",
            dependencies: ["TheaModels"],
            path: "Shared/Core/Interfaces",
            swiftSettings: [
                .define("THEA_INTERFACES_ONLY")
            ]
        ),

        // LAYER 3: Mock services for testing - depends on Interfaces
        // Note: Only mock implementations included; concrete services (ChatService, ProjectService)
        // excluded as they depend on SwiftData and are for future app integration
        .target(
            name: "TheaServices",
            dependencies: ["TheaInterfaces"],
            path: "Shared/Core/Services",
            exclude: [
                "ChatService.swift",
                "ConversationExporter.swift",
                "ProjectService.swift",
                "ProjectPathManager.swift",
                "QAToolsManager.swift",
                "SecureStorage.swift",
                "SpotlightService.swift"
            ],
            swiftSettings: [
                .define("THEA_SERVICES_MOCK")
            ]
        ),

        // Test targets
        .testTarget(
            name: "TheaModelsTests",
            dependencies: ["TheaModels"],
            path: "Tests/CoreTests/ModelTests"
        ),
        .testTarget(
            name: "TheaInterfacesTests",
            dependencies: ["TheaInterfaces"],
            path: "Tests/CoreTests/FoundationTests"
        ),
        .testTarget(
            name: "TheaServicesTests",
            dependencies: ["TheaServices"],
            path: "Tests/CoreTests/ServiceTests"
        )
    ]
)
