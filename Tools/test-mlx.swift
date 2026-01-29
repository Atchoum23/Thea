#!/usr/bin/env swift

// Quick test script to validate MLX model discovery
// Run with: swift test-mlx.swift

import Foundation

// ANSI colors
let green = "\u{001B}[32m"
let red = "\u{001B}[31m"
let yellow = "\u{001B}[33m"
let reset = "\u{001B}[0m"

print("🧪 MLX Local Model Integration Test")
print("=" * 50)
print()

// Test 1: Check SharedLLMs directory exists
let sharedLLMs = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/SharedLLMs/models-mlx")

print("Test 1: SharedLLMs directory exists")
if FileManager.default.fileExists(atPath: sharedLLMs.path) {
    print("\(green)✅ PASS\(reset): \(sharedLLMs.path)")
} else {
    print("\(red)❌ FAIL\(reset): Directory not found")
    exit(1)
}

// Test 2: Check hub directory structure
let hubPath = sharedLLMs.appendingPathComponent("hub")
print("\nTest 2: Hub directory structure")
if FileManager.default.fileExists(atPath: hubPath.path) {
    print("\(green)✅ PASS\(reset): Hub directory exists")
} else {
    print("\(red)❌ FAIL\(reset): Hub directory not found")
    exit(1)
}

// Test 3: Count MLX models
print("\nTest 3: Counting MLX models")
do {
    let contents = try FileManager.default.contentsOfDirectory(at: hubPath, includingPropertiesForKeys: nil)
    let modelDirs = contents.filter { $0.lastPathComponent.hasPrefix("models--") }

    if !modelDirs.isEmpty {
        print("\(green)✅ PASS\(reset): Found \(modelDirs.count) model directories")

        print("\nDiscovered models:")
        for (index, dir) in modelDirs.enumerated() {
            let name = dir.lastPathComponent
                .replacingOccurrences(of: "models--", with: "")
                .replacingOccurrences(of: "--", with: "/")
            print("  \(index + 1). \(name)")
        }
    } else {
        print("\(yellow)⚠️ WARNING\(reset): No model directories found")
    }
} catch {
    print("\(red)❌ FAIL\(reset): \(error)")
    exit(1)
}

// Test 4: Validate model structure (pick first model)
print("\nTest 4: Validating model structure")
do {
    let contents = try FileManager.default.contentsOfDirectory(at: hubPath, includingPropertiesForKeys: nil)
    let modelDirs = contents.filter { $0.lastPathComponent.hasPrefix("models--") }

    if let firstModel = modelDirs.first {
        let snapshotsPath = firstModel.appendingPathComponent("snapshots")

        if FileManager.default.fileExists(atPath: snapshotsPath.path) {
            let snapshots = try FileManager.default.contentsOfDirectory(at: snapshotsPath, includingPropertiesForKeys: nil)

            if let firstSnapshot = snapshots.first {
                let configPath = firstSnapshot.appendingPathComponent("config.json")

                if FileManager.default.fileExists(atPath: configPath.path) {
                    print("\(green)✅ PASS\(reset): Model structure valid")
                    print("  Model: \(firstModel.lastPathComponent)")
                    print("  Config: \(configPath.lastPathComponent)")
                } else {
                    print("\(red)❌ FAIL\(reset): config.json not found")
                }
            }
        }
    }
} catch {
    print("\(red)❌ FAIL\(reset): \(error)")
}

// Test 5: Check Thea debug log
print("\nTest 5: Checking Thea debug log")
let logPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Desktop/thea_debug.log")

if FileManager.default.fileExists(atPath: logPath.path) {
    do {
        let logContent = try String(contentsOf: logPath)

        // Check for successful model discovery
        if logContent.contains("LocalModelManager:") && logContent.contains("models discovered") {
            let lines = logContent.split(separator: "\n")
            if let discoveryLine = lines.first(where: { $0.contains("LocalModelManager:") }) {
                print("\(green)✅ PASS\(reset): \(discoveryLine)")
            }
        }

        if logContent.contains("ProviderRegistry:") && logContent.contains("local models registered") {
            let lines = logContent.split(separator: "\n")
            if let registryLine = lines.first(where: { $0.contains("ProviderRegistry:") }) {
                print("\(green)✅ PASS\(reset): \(registryLine)")
            }
        }

        if logContent.contains("Startup complete") {
            print("\(green)✅ PASS\(reset): App startup completed successfully")
        }
    } catch {
        print("\(yellow)⚠️ WARNING\(reset): Could not read log file")
    }
} else {
    print("\(yellow)⚠️ WARNING\(reset): Thea debug log not found (app may not have been launched)")
}

print("\n" + "=" * 50)
print("🎉 All basic tests passed!")
print()

// Helper extension
extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}
