// IntegratedTestRunner.swift
// Thea V2
//
// Native test execution for multiple languages
// Supports Swift XCTest, Python pytest/unittest, Node.js Jest/Mocha
// Enables Replit-style self-testing capabilities
//
// Note: Test execution (IntegratedTestRunner actor) is macOS-only as it uses Process

import Foundation
import OSLog

// Supporting types are in IntegratedTestRunnerTypes.swift
// Test execution methods in IntegratedTestRunner+TestExecution.swift
// Result parsing methods in IntegratedTestRunner+ResultParsing.swift

#if os(macOS)

// MARK: - Integrated Test Runner

/// Runs tests across multiple languages and frameworks
@MainActor
@Observable
public final class IntegratedTestRunner {
    public static let shared = IntegratedTestRunner()

    let logger = Logger(subsystem: "ai.thea.app", category: "IntegratedTestRunner")

    // MARK: - State

    var isRunning = false
    var currentConfiguration: TestRunConfiguration?
    var recentResults: [TestRunResult] = []
    private(set) var runningTests: [String] = []

    // MARK: - Configuration

    /// Maximum concurrent test processes
    public var maxConcurrentRuns: Int = 4

    /// Default timeout per test suite
    public var defaultTimeout: TimeInterval = 300

    /// Auto-detect test framework from project
    public var autoDetectFramework: Bool = true

    var activeProcesses: [UUID: Process] = [:]

    private init() {}

    // MARK: - Framework Detection

    /// Detect test framework from project structure
    public func detectFramework(at projectPath: String) async -> TestFramework? {
        let fileManager = FileManager.default

        // Check for Swift package
        let packageSwift = (projectPath as NSString).appendingPathComponent("Package.swift")
        if fileManager.fileExists(atPath: packageSwift) {
            return .swiftTesting
        }

        // Check for Xcode project
        let xcodeProj: String?
        do {
            xcodeProj = try fileManager.contentsOfDirectory(atPath: projectPath)
                .first { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
        } catch {
            logger.error("Failed to list directory for Xcode project detection: \(error.localizedDescription)")
            xcodeProj = nil
        }
        if xcodeProj != nil {
            return .xctest
        }

        // Check for package.json (Node.js)
        let packageJson = (projectPath as NSString).appendingPathComponent("package.json")
        if fileManager.fileExists(atPath: packageJson) {
            // Read package.json to detect framework
            if let data = fileManager.contents(atPath: packageJson) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let deps = (json["devDependencies"] as? [String: Any]) ?? [:]
                        let allDeps = deps.merging((json["dependencies"] as? [String: Any]) ?? [:]) { $1 }

                        if allDeps["jest"] != nil { return .jest }
                        if allDeps["mocha"] != nil { return .mocha }
                        if allDeps["vitest"] != nil { return .vitest }
                    }
                } catch {
                    logger.error("Failed to parse package.json: \(error.localizedDescription)")
                }
            }
            return .jest  // Default for Node.js
        }

        // Check for Python
        let pytestIni = (projectPath as NSString).appendingPathComponent("pytest.ini")
        let setupPy = (projectPath as NSString).appendingPathComponent("setup.py")
        let pyprojectToml = (projectPath as NSString).appendingPathComponent("pyproject.toml")

        if fileManager.fileExists(atPath: pytestIni) {
            return .pytest
        }
        if fileManager.fileExists(atPath: setupPy) || fileManager.fileExists(atPath: pyprojectToml) {
            return .pytest
        }

        // Check for Go
        let goMod = (projectPath as NSString).appendingPathComponent("go.mod")
        if fileManager.fileExists(atPath: goMod) {
            return .goTest
        }

        // Check for Rust
        let cargoToml = (projectPath as NSString).appendingPathComponent("Cargo.toml")
        if fileManager.fileExists(atPath: cargoToml) {
            return .rustCargo
        }

        return nil
    }

    // MARK: - Cleanup

    /// Cancel all running tests
    public func cancelAll() {
        for (_, process) in activeProcesses {
            if process.isRunning {
                process.terminate()
            }
        }
        activeProcesses.removeAll()
        isRunning = false
    }
}

#endif  // os(macOS)
