// AgentSecKillSwitchTests.swift
// Tests for AgentSec kill switch

@testable import TheaCore
import XCTest

@MainActor
final class AgentSecKillSwitchTests: XCTestCase {
    var killSwitch: AgentSecKillSwitch!

    override func setUp() async throws {
        killSwitch = AgentSecKillSwitch.shared
        killSwitch.forceReset()
        AgentSecPolicy.shared.enableStrictMode()
    }

    override func tearDown() async throws {
        killSwitch.forceReset()
    }

    // MARK: - Trigger Tests

    func testKillSwitchTriggersCorrectly() {
        killSwitch.trigger(reason: "Test critical violation")

        XCTAssertTrue(killSwitch.isTriggered)
        XCTAssertTrue(killSwitch.shouldHalt())
        XCTAssertEqual(killSwitch.triggerReason, "Test critical violation")
        XCTAssertNotNil(killSwitch.triggerTimestamp)
    }

    func testKillSwitchIncrementsTriggerCount() {
        let initialCount = killSwitch.triggerCount

        killSwitch.trigger(reason: "First trigger")
        killSwitch.forceReset()
        killSwitch.trigger(reason: "Second trigger")

        XCTAssertEqual(killSwitch.triggerCount, initialCount + 2)
    }

    func testShouldHaltReturnsFalseWhenNotTriggered() {
        XCTAssertFalse(killSwitch.shouldHalt())
        XCTAssertNil(killSwitch.haltReason())
    }

    func testShouldHaltReturnsTrueWhenTriggered() {
        killSwitch.trigger(reason: "Test violation")

        XCTAssertTrue(killSwitch.shouldHalt())
        XCTAssertEqual(killSwitch.haltReason(), "Test violation")
    }

    // MARK: - Reset Tests

    func testResetRequiresConfirmation() {
        killSwitch.trigger(reason: "Test violation")

        // Invalid confirmation should fail
        let result1 = killSwitch.reset(confirmation: "wrong")
        XCTAssertFalse(result1)
        XCTAssertTrue(killSwitch.isTriggered)

        // Valid confirmation should succeed
        let result2 = killSwitch.reset(confirmation: "RESET_KILL_SWITCH")
        XCTAssertTrue(result2)
        XCTAssertFalse(killSwitch.isTriggered)
    }

    func testResetClearsState() {
        killSwitch.trigger(reason: "Test violation")

        XCTAssertTrue(killSwitch.reset(confirmation: "RESET_KILL_SWITCH"))

        XCTAssertFalse(killSwitch.isTriggered)
        XCTAssertNil(killSwitch.triggerReason)
    }

    // MARK: - Callback Tests

    func testTriggerCallbackIsCalled() {
        var callbackReason: String?
        killSwitch.onTrigger = { reason in
            callbackReason = reason
        }

        killSwitch.trigger(reason: "Callback test")

        XCTAssertEqual(callbackReason, "Callback test")
    }

    func testResetCallbackIsCalled() {
        var resetCalled = false
        killSwitch.onReset = {
            resetCalled = true
        }

        killSwitch.trigger(reason: "Test")
        _ = killSwitch.reset(confirmation: "RESET_KILL_SWITCH")

        XCTAssertTrue(resetCalled)
    }

    // MARK: - Integration Tests

    func testKillSwitchBlocksOperations() async throws {
        killSwitch.trigger(reason: "Critical violation")

        var wasHalted = false
        let result: String? = await KillSwitchGuard.execute {
            "Operation completed"
        } onHalted: { _ in
            wasHalted = true
        }

        XCTAssertNil(result)
        XCTAssertTrue(wasHalted)
    }

    func testKillSwitchAllowsOperationsWhenNotTriggered() async throws {
        let result: String? = await KillSwitchGuard.execute {
            "Operation completed"
        } onHalted: { _ in
            XCTFail("Should not halt")
        }

        XCTAssertEqual(result, "Operation completed")
    }
}
