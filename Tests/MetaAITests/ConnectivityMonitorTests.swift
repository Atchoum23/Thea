// ConnectivityMonitorTests.swift
// Tests for the Connectivity Monitor

@testable import TheaCore
import XCTest

// MARK: - ConnectivityMonitor Tests

@MainActor
final class ConnectivityMonitorTests: XCTestCase {
    // MARK: - Singleton Tests

    func testSingletonExists() {
        let monitor = ConnectivityMonitor.shared
        XCTAssertNotNil(monitor)
    }

    func testSingletonIsSameInstance() {
        let monitor1 = ConnectivityMonitor.shared
        let monitor2 = ConnectivityMonitor.shared
        XCTAssertTrue(monitor1 === monitor2)
    }

    // MARK: - Status Tests

    func testCurrentStatusAccessible() {
        let monitor = ConnectivityMonitor.shared
        let status = monitor.currentStatus
        XCTAssertNotNil(status)
    }

    func testIsConnectedAccessible() {
        let monitor = ConnectivityMonitor.shared
        // Just test that it doesn't crash
        _ = monitor.isConnected
    }

    func testIsExpensiveAccessible() {
        let monitor = ConnectivityMonitor.shared
        // Just test that it doesn't crash
        _ = monitor.isExpensive
    }

    // MARK: - Recommended Execution Mode Tests

    func testRecommendedExecutionModeAccessible() {
        let monitor = ConnectivityMonitor.shared
        let mode = monitor.recommendedExecutionMode
        XCTAssertNotNil(mode)
    }

    // MARK: - Disconnection History Tests

    func testRecentDisconnectionsAccessible() {
        let monitor = ConnectivityMonitor.shared
        let disconnections = monitor.recentDisconnections
        XCTAssertNotNil(disconnections)
    }

    // MARK: - Status Summary Tests

    func testStatusSummaryNotEmpty() {
        let monitor = ConnectivityMonitor.shared
        let summary = monitor.statusSummary
        XCTAssertFalse(summary.isEmpty)
    }

    // MARK: - Monitoring Control Tests

    func testStartMonitoringDoesNotCrash() {
        let monitor = ConnectivityMonitor.shared
        monitor.startMonitoring()
        // If we get here without crash, test passes
    }

    func testStopMonitoringDoesNotCrash() {
        let monitor = ConnectivityMonitor.shared
        monitor.stopMonitoring()
        // If we get here without crash, test passes
    }

    func testRestartMonitoring() {
        let monitor = ConnectivityMonitor.shared
        monitor.stopMonitoring()
        monitor.startMonitoring()
        // If we get here without crash, test passes
    }
}

// MARK: - ConnectivityStatus Tests

@MainActor
final class ConnectivityStatusTests: XCTestCase {
    func testConnectivityStatusValues() {
        XCTAssertNotNil(ConnectivityStatus.connected)
        XCTAssertNotNil(ConnectivityStatus.disconnected)
        XCTAssertNotNil(ConnectivityStatus.expensive)
        XCTAssertNotNil(ConnectivityStatus.constrained)
    }

    func testConnectivityStatusEquality() {
        XCTAssertEqual(ConnectivityStatus.connected, ConnectivityStatus.connected)
        XCTAssertNotEqual(ConnectivityStatus.connected, ConnectivityStatus.disconnected)
    }

    func testConnectivityStatusIsSendable() {
        let status = ConnectivityStatus.connected
        // This test passes if it compiles - ConnectivityStatus must be Sendable
        let _: Sendable = status
    }
}

// MARK: - NetworkExecutionMode Tests

@MainActor
final class NetworkExecutionModeTests: XCTestCase {
    func testNetworkExecutionModeValues() {
        XCTAssertNotNil(NetworkExecutionMode.normal)
        XCTAssertNotNil(NetworkExecutionMode.preferLocal)
        XCTAssertNotNil(NetworkExecutionMode.localOnly)
    }

    func testNetworkExecutionModeRawValues() {
        XCTAssertEqual(NetworkExecutionMode.normal.rawValue, "Normal")
        XCTAssertEqual(NetworkExecutionMode.preferLocal.rawValue, "Prefer Local")
        XCTAssertEqual(NetworkExecutionMode.localOnly.rawValue, "Local Only")
    }

    func testNetworkExecutionModeIsSendable() {
        let mode = NetworkExecutionMode.normal
        // This test passes if it compiles - NetworkExecutionMode must be Sendable
        let _: Sendable = mode
    }
}

// MARK: - ConnectivityEvent Tests

@MainActor
final class ConnectivityEventTests: XCTestCase {
    func testConnectivityEventCreation() {
        let event = ConnectivityEvent(
            timestamp: Date(),
            from: .connected,
            to: .disconnected,
            interfaces: ["en0"]
        )

        XCTAssertNotNil(event.timestamp)
        XCTAssertEqual(event.from, .connected)
        XCTAssertEqual(event.to, .disconnected)
        XCTAssertEqual(event.interfaces, ["en0"])
    }

    func testConnectivityEventMultipleInterfaces() {
        let event = ConnectivityEvent(
            timestamp: Date(),
            from: .disconnected,
            to: .connected,
            interfaces: ["en0", "en1", "utun0"]
        )

        XCTAssertEqual(event.interfaces.count, 3)
        XCTAssertTrue(event.interfaces.contains("en0"))
    }

    func testConnectivityEventIsSendable() {
        let event = ConnectivityEvent(
            timestamp: Date(),
            from: .connected,
            to: .connected,
            interfaces: []
        )
        // This test passes if it compiles - ConnectivityEvent must be Sendable
        let _: Sendable = event
    }
}
