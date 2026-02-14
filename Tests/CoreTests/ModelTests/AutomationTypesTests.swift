// AutomationTypesTests.swift
// Tests for AutomationLevel and AutomationStats from AutomatableSuggestionEngineTypes

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum AutomationLevel: Int, CaseIterable, Comparable {
    case manualOnly = 0
    case suggestOnly = 1
    case confirmEach = 2
    case preApproved = 3
    case fullyAutomated = 4

    static func < (lhs: AutomationLevel, rhs: AutomationLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .manualOnly: "Manual Only"
        case .suggestOnly: "Suggest Only"
        case .confirmEach: "Confirm Each Time"
        case .preApproved: "Pre-Approved"
        case .fullyAutomated: "Fully Automated"
        }
    }

    var emoji: String {
        switch self {
        case .manualOnly: "\u{1F512}"       // lock
        case .suggestOnly: "\u{1F4A1}"      // lightbulb
        case .confirmEach: "\u{270B}"        // raised hand
        case .preApproved: "\u{2705}"        // checkmark
        case .fullyAutomated: "\u{1F916}"   // robot
        }
    }
}

private struct AutomationStats {
    let totalSuggestions: Int
    let automatedCount: Int
    let successRate: Double
    let helpfulRate: Double
    let totalTimeSaved: TimeInterval
    let categoryBreakdown: [String: Int]

    var automationRate: Double {
        totalSuggestions > 0 ? Double(automatedCount) / Double(totalSuggestions) : 0
    }

    var formattedTimeSaved: String {
        let hours = Int(totalTimeSaved / 3600)
        let minutes = Int((totalTimeSaved.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - AutomationLevel Tests

final class AutomationLevelTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(AutomationLevel.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(AutomationLevel.manualOnly.rawValue, 0)
        XCTAssertEqual(AutomationLevel.suggestOnly.rawValue, 1)
        XCTAssertEqual(AutomationLevel.confirmEach.rawValue, 2)
        XCTAssertEqual(AutomationLevel.preApproved.rawValue, 3)
        XCTAssertEqual(AutomationLevel.fullyAutomated.rawValue, 4)
    }

    func testComparableOrdering() {
        XCTAssertTrue(AutomationLevel.manualOnly < .suggestOnly)
        XCTAssertTrue(AutomationLevel.suggestOnly < .confirmEach)
        XCTAssertTrue(AutomationLevel.confirmEach < .preApproved)
        XCTAssertTrue(AutomationLevel.preApproved < .fullyAutomated)
    }

    func testManualOnlyIsLowest() {
        for level in AutomationLevel.allCases where level != .manualOnly {
            XCTAssertTrue(.manualOnly < level, "manualOnly should be less than \(level.description)")
        }
    }

    func testFullyAutomatedIsHighest() {
        for level in AutomationLevel.allCases where level != .fullyAutomated {
            XCTAssertTrue(level < .fullyAutomated, "\(level.description) should be less than fullyAutomated")
        }
    }

    func testDescriptionsNonEmpty() {
        for level in AutomationLevel.allCases {
            XCTAssertFalse(level.description.isEmpty, "\(level) must have a description")
        }
    }

    func testDescriptions() {
        XCTAssertEqual(AutomationLevel.manualOnly.description, "Manual Only")
        XCTAssertEqual(AutomationLevel.suggestOnly.description, "Suggest Only")
        XCTAssertEqual(AutomationLevel.confirmEach.description, "Confirm Each Time")
        XCTAssertEqual(AutomationLevel.preApproved.description, "Pre-Approved")
        XCTAssertEqual(AutomationLevel.fullyAutomated.description, "Fully Automated")
    }

    func testEmojisNonEmpty() {
        for level in AutomationLevel.allCases {
            XCTAssertFalse(level.emoji.isEmpty, "\(level) must have an emoji")
        }
    }

    func testUniqueEmojis() {
        let emojis = AutomationLevel.allCases.map(\.emoji)
        XCTAssertEqual(emojis.count, Set(emojis).count, "All emojis must be unique")
    }

    func testEqualityReflexive() {
        for level in AutomationLevel.allCases {
            let copy = level
            XCTAssertEqual(copy, level)
            XCTAssertFalse(copy < level)
        }
    }
}

// MARK: - AutomationStats Tests

final class AutomationStatsTests: XCTestCase {

    func testAutomationRateNormal() {
        let stats = AutomationStats(
            totalSuggestions: 100, automatedCount: 75,
            successRate: 0.9, helpfulRate: 0.85,
            totalTimeSaved: 3600, categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.automationRate, 0.75)
    }

    func testAutomationRateZeroSuggestions() {
        let stats = AutomationStats(
            totalSuggestions: 0, automatedCount: 0,
            successRate: 0, helpfulRate: 0,
            totalTimeSaved: 0, categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.automationRate, 0.0)
    }

    func testAutomationRatePerfect() {
        let stats = AutomationStats(
            totalSuggestions: 50, automatedCount: 50,
            successRate: 1.0, helpfulRate: 1.0,
            totalTimeSaved: 7200, categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.automationRate, 1.0)
    }

    func testFormattedTimeSavedHoursAndMinutes() {
        let stats = AutomationStats(
            totalSuggestions: 10, automatedCount: 5,
            successRate: 0.8, helpfulRate: 0.7,
            totalTimeSaved: 5400, // 1h 30m
            categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.formattedTimeSaved, "1h 30m")
    }

    func testFormattedTimeSavedMinutesOnly() {
        let stats = AutomationStats(
            totalSuggestions: 10, automatedCount: 5,
            successRate: 0.8, helpfulRate: 0.7,
            totalTimeSaved: 2700, // 45m
            categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.formattedTimeSaved, "45m")
    }

    func testFormattedTimeSavedZero() {
        let stats = AutomationStats(
            totalSuggestions: 0, automatedCount: 0,
            successRate: 0, helpfulRate: 0,
            totalTimeSaved: 0,
            categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.formattedTimeSaved, "0m")
    }

    func testFormattedTimeSavedExactHour() {
        let stats = AutomationStats(
            totalSuggestions: 10, automatedCount: 5,
            successRate: 0.8, helpfulRate: 0.7,
            totalTimeSaved: 7200, // 2h 0m
            categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.formattedTimeSaved, "2h 0m")
    }

    func testFormattedTimeSavedLargeValue() {
        let stats = AutomationStats(
            totalSuggestions: 1000, automatedCount: 800,
            successRate: 0.95, helpfulRate: 0.9,
            totalTimeSaved: 360_000, // 100h 0m
            categoryBreakdown: [:]
        )
        XCTAssertEqual(stats.formattedTimeSaved, "100h 0m")
    }

    func testCategoryBreakdown() {
        let breakdown: [String: Int] = [
            "send_message": 10,
            "schedule_event": 5,
            "set_reminder": 3
        ]
        let stats = AutomationStats(
            totalSuggestions: 18, automatedCount: 12,
            successRate: 0.9, helpfulRate: 0.85,
            totalTimeSaved: 1800,
            categoryBreakdown: breakdown
        )
        XCTAssertEqual(stats.categoryBreakdown.count, 3)
        XCTAssertEqual(stats.categoryBreakdown["send_message"], 10)
    }
}
