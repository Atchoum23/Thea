// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TheaWeb",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Vapor web framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // Fluent ORM
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // SQLite driver for development
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
        // JWT for Sign in with Apple
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.0"),
        // Redis for rate limiting and sessions
        .package(url: "https://github.com/vapor/redis.git", from: "4.10.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Redis", package: "redis")
            ],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor")
            ],
            path: "Tests/AppTests"
        )
    ]
)
