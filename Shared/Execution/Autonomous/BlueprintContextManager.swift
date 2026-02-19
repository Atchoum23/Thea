// BlueprintContextManager.swift
// Thea V2
//
// Manages execution context and handles compaction for long operations.
// Extracted from BlueprintExecutor.swift for file length compliance.

import Foundation

// MARK: - Context Manager

/// Manages execution context and handles compaction for long operations
@MainActor
// periphery:ignore - Reserved: BlueprintContextManager class — reserved for future feature activation
final class BlueprintContextManager {
    // periphery:ignore - Reserved: BlueprintContextManager type reserved for future feature activation
    private var context: [String: Any] = [:]
    private var history: [BlueprintContextSnapshot] = []
    private let maxHistorySize = 100

    func set(_ key: String, value: Any) {
        context[key] = value
    }

    func get<T>(_ key: String) -> T? {
        context[key] as? T
    }

    func snapshot() {
        let snap = BlueprintContextSnapshot(timestamp: Date(), context: context)
        history.append(snap)

        if history.count > maxHistorySize {
            compactHistory()
        }
    }

    private func compactHistory() {
        // Keep first, last, and every 10th snapshot
        var compacted: [BlueprintContextSnapshot] = []
        for (index, snapshot) in history.enumerated() {
            if index == 0 || index == history.count - 1 || index % 10 == 0 {
                compacted.append(snapshot)
            }
        }
        history = compacted
    }
}

// periphery:ignore - Reserved: BlueprintContextSnapshot type reserved for future feature activation
private struct BlueprintContextSnapshot {
    let timestamp: Date
    let context: [String: Any]
}
