//
//  BadgeManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import os.log
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - Badge Manager

/// Manages app badge counts and display
@MainActor
@Observable
public final class BadgeManager {
    private let logger = Logger(subsystem: "ai.thea.app", category: "BadgeManager")
    public static let shared = BadgeManager()

    private let defaults = UserDefaults.standard
    private let badgeCountKey = "BadgeManager.badgeCount"
    private let categoryCountsKey = "BadgeManager.categoryCounts"

    // MARK: - State

    /// Current total badge count
    public private(set) var badgeCount: Int = 0

    /// Badge counts per category
    public private(set) var categoryCounts: [NotificationCategory: Int] = [:]

    /// Whether badge display is enabled
    public var badgeEnabled: Bool = true {
        didSet {
            defaults.set(badgeEnabled, forKey: "BadgeManager.badgeEnabled")
            if !badgeEnabled {
                clearBadge()
            } else {
                updateAppBadge()
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadState()
    }

    private func loadState() {
        badgeEnabled = defaults.bool(forKey: "BadgeManager.badgeEnabled")
        badgeCount = defaults.integer(forKey: badgeCountKey)

        if let data = defaults.data(forKey: categoryCountsKey) {
            do {
                let counts = try JSONDecoder().decode([String: Int].self, from: data)
                categoryCounts = counts.reduce(into: [:]) { result, pair in
                    if let category = NotificationCategory(rawValue: pair.key) {
                        result[category] = pair.value
                    }
                }
            } catch {
                logger.error("BadgeManager: failed to decode category counts: \(error.localizedDescription)")
            }
        }

        // Sync badge on launch
        updateAppBadge()
    }

    private func saveState() {
        defaults.set(badgeCount, forKey: badgeCountKey)

        let stringKeyCounts = categoryCounts.reduce(into: [String: Int]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }

        do {
            let data = try JSONEncoder().encode(stringKeyCounts)
            defaults.set(data, forKey: categoryCountsKey)
        } catch {
            logger.error("BadgeManager: failed to encode category counts: \(error.localizedDescription)")
        }
    }

    // MARK: - Badge Operations

    /// Increment badge count
    public func increment(category: NotificationCategory = .general, by amount: Int = 1) {
        categoryCounts[category, default: 0] += amount
        badgeCount += amount
        saveState()
        updateAppBadge()
    }

    /// Decrement badge count
    public func decrement(category: NotificationCategory = .general, by amount: Int = 1) {
        let currentCategoryCount = categoryCounts[category, default: 0]
        let decrementAmount = Swift.min(amount, currentCategoryCount)

        categoryCounts[category] = Swift.max(0, currentCategoryCount - decrementAmount)
        badgeCount = Swift.max(0, badgeCount - decrementAmount)

        // Clean up zero counts
        if categoryCounts[category] == 0 {
            categoryCounts.removeValue(forKey: category)
        }

        saveState()
        updateAppBadge()
    }

    /// Set badge count for a category
    public func setBadge(category: NotificationCategory, count: Int) {
        let previousCount = categoryCounts[category, default: 0]
        let difference = count - previousCount

        categoryCounts[category] = count
        badgeCount = Swift.max(0, badgeCount + difference)

        // Clean up zero counts
        if count == 0 {
            categoryCounts.removeValue(forKey: category)
        }

        saveState()
        updateAppBadge()
    }

    /// Clear badge for a specific category
    public func clearBadge(for category: NotificationCategory) {
        let count = categoryCounts[category, default: 0]
        categoryCounts.removeValue(forKey: category)
        badgeCount = Swift.max(0, badgeCount - count)
        saveState()
        updateAppBadge()
    }

    /// Clear all badges
    public func clearBadge() {
        badgeCount = 0
        categoryCounts.removeAll()
        saveState()
        updateAppBadge()
    }

    /// Get badge count for a category
    public func getBadgeCount(for category: NotificationCategory) -> Int {
        categoryCounts[category, default: 0]
    }

    // MARK: - App Badge Update

    private func updateAppBadge() {
        guard badgeEnabled else {
            setAppBadge(0)
            return
        }

        setAppBadge(badgeCount)
    }

    private func setAppBadge(_ count: Int) {
        #if os(macOS)
            if count > 0 {
                NSApplication.shared.dockTile.badgeLabel = "\(count)"
            } else {
                NSApplication.shared.dockTile.badgeLabel = nil
            }
        #else
            Task {
                do {
                    try await UNUserNotificationCenter.current().setBadgeCount(count)
                } catch {
                    // Handle error silently - badge update is non-critical
                }
            }
        #endif
    }

    // MARK: - Badge Summary

    /// Get a summary of all badge counts
    public var badgeSummary: BadgeSummary {
        BadgeSummary(
            total: badgeCount,
            categoryCounts: categoryCounts,
            lastUpdated: Date()
        )
    }
}

// MARK: - Badge Summary

public struct BadgeSummary: Sendable {
    public let total: Int
    public let categoryCounts: [NotificationCategory: Int]
    public let lastUpdated: Date

    public var hasUnread: Bool {
        total > 0
    }

    public var topCategory: NotificationCategory? {
        categoryCounts.max { $0.value < $1.value }?.key
    }
}

// MARK: - Badge Configuration

public struct BadgeConfiguration: Codable, Sendable, Equatable {
    /// Whether to show badge on dock/app icon
    public var showBadge: Bool = true

    /// Whether to include AI response counts
    public var includeAIResponses: Bool = true

    /// Whether to include task completion counts
    public var includeTaskCompletions: Bool = false

    /// Whether to include reminder counts
    public var includeReminders: Bool = true

    /// Categories to exclude from badge count
    public var excludedCategories: Set<NotificationCategory> = [.sync, .system]

    /// Maximum badge number to display (0 for unlimited)
    public var maxBadgeNumber: Int = 99

    public init() {}
}

// MARK: - Badge View Helper

#if os(macOS)
    import SwiftUI

    public struct BadgeView: View {
        let count: Int
        let color: Color

        public init(count: Int, color: Color = .red) {
            self.count = count
            self.color = color
        }

        public var body: some View {
            // swiftlint:disable:next empty_count
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())
            }
        }
    }

    public extension View {
        /// Add a badge overlay to a view
        func badge(_ count: Int, color: Color = .red) -> some View {
            overlay(alignment: .topTrailing) {
                BadgeView(count: count, color: color)
                    .offset(x: 8, y: -8)
            }
        }

        /// Add a category badge overlay
        func categoryBadge(_ category: NotificationCategory) -> some View {
            let count = BadgeManager.shared.getBadgeCount(for: category)
            return badge(count)
        }
    }
#endif
