// TheaAgentSessionTests.swift
// Tests for TheaAgentSession value types: state, message, artifact, context pressure

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum TheaAgentState: String, CaseIterable, Codable {
    case idle, planning, working, awaitingApproval, paused, completed, failed, cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }

    var isActive: Bool {
        switch self {
        case .planning, .working, .awaitingApproval: true
        default: false
        }
    }

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .planning: "Planning"
        case .working: "Working"
        case .awaitingApproval: "Awaiting Approval"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var sfSymbol: String {
        switch self {
        case .idle: "circle"
        case .planning: "brain"
        case .working: "gearshape.2.fill"
        case .awaitingApproval: "hand.raised.fill"
        case .paused: "pause.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }
}

private struct TheaAgentMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String {
        case system, user, agent
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

private struct TheaAgentArtifact: Identifiable {
    let id: UUID
    let title: String
    let type: ArtifactType
    let content: String
    let createdAt: Date

    enum ArtifactType: String {
        case code, text, markdown, json, plan, summary
    }

    init(id: UUID = UUID(), title: String, type: ArtifactType, content: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }
}

private enum TheaContextPressure: String, Comparable {
    case nominal, elevated, critical, exceeded

    static func < (lhs: TheaContextPressure, rhs: TheaContextPressure) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .nominal: 0
        case .elevated: 1
        case .critical: 2
        case .exceeded: 3
        }
    }

    static func from(usage: Double) -> TheaContextPressure {
        switch usage {
        case ..<0.6: .nominal
        case ..<0.8: .elevated
        case ..<0.95: .critical
        default: .exceeded
        }
    }
}

// MARK: - TheaAgentState Tests

final class TheaAgentStateTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TheaAgentState.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(TheaAgentState.idle.rawValue, "idle")
        XCTAssertEqual(TheaAgentState.planning.rawValue, "planning")
        XCTAssertEqual(TheaAgentState.working.rawValue, "working")
        XCTAssertEqual(TheaAgentState.awaitingApproval.rawValue, "awaitingApproval")
        XCTAssertEqual(TheaAgentState.paused.rawValue, "paused")
        XCTAssertEqual(TheaAgentState.completed.rawValue, "completed")
        XCTAssertEqual(TheaAgentState.failed.rawValue, "failed")
        XCTAssertEqual(TheaAgentState.cancelled.rawValue, "cancelled")
    }

    func testTerminalStates() {
        let terminal: [TheaAgentState] = [.completed, .failed, .cancelled]
        for state in terminal {
            XCTAssertTrue(state.isTerminal, "\(state.rawValue) should be terminal")
        }
    }

    func testNonTerminalStates() {
        let nonTerminal: [TheaAgentState] = [.idle, .planning, .working, .awaitingApproval, .paused]
        for state in nonTerminal {
            XCTAssertFalse(state.isTerminal, "\(state.rawValue) should not be terminal")
        }
    }

    func testActiveStates() {
        let active: [TheaAgentState] = [.planning, .working, .awaitingApproval]
        for state in active {
            XCTAssertTrue(state.isActive, "\(state.rawValue) should be active")
        }
    }

    func testInactiveStates() {
        let inactive: [TheaAgentState] = [.idle, .paused, .completed, .failed, .cancelled]
        for state in inactive {
            XCTAssertFalse(state.isActive, "\(state.rawValue) should not be active")
        }
    }

    func testTerminalAndActiveAreMutuallyExclusive() {
        for state in TheaAgentState.allCases {
            if state.isTerminal {
                XCTAssertFalse(
                    state.isActive,
                    "\(state.rawValue) cannot be both terminal and active"
                )
            }
        }
    }

    func testDisplayNames() {
        XCTAssertEqual(TheaAgentState.idle.displayName, "Idle")
        XCTAssertEqual(TheaAgentState.planning.displayName, "Planning")
        XCTAssertEqual(TheaAgentState.working.displayName, "Working")
        XCTAssertEqual(TheaAgentState.awaitingApproval.displayName, "Awaiting Approval")
        XCTAssertEqual(TheaAgentState.paused.displayName, "Paused")
        XCTAssertEqual(TheaAgentState.completed.displayName, "Completed")
        XCTAssertEqual(TheaAgentState.failed.displayName, "Failed")
        XCTAssertEqual(TheaAgentState.cancelled.displayName, "Cancelled")
    }

    func testAllDisplayNamesNonEmpty() {
        for state in TheaAgentState.allCases {
            XCTAssertFalse(
                state.displayName.isEmpty,
                "\(state.rawValue) must have a display name"
            )
        }
    }

    func testSFSymbols() {
        XCTAssertEqual(TheaAgentState.idle.sfSymbol, "circle")
        XCTAssertEqual(TheaAgentState.planning.sfSymbol, "brain")
        XCTAssertEqual(TheaAgentState.working.sfSymbol, "gearshape.2.fill")
        XCTAssertEqual(TheaAgentState.awaitingApproval.sfSymbol, "hand.raised.fill")
        XCTAssertEqual(TheaAgentState.paused.sfSymbol, "pause.circle.fill")
        XCTAssertEqual(TheaAgentState.completed.sfSymbol, "checkmark.circle.fill")
        XCTAssertEqual(TheaAgentState.failed.sfSymbol, "xmark.circle.fill")
        XCTAssertEqual(TheaAgentState.cancelled.sfSymbol, "stop.circle.fill")
    }

    func testAllSFSymbolsNonEmpty() {
        for state in TheaAgentState.allCases {
            XCTAssertFalse(
                state.sfSymbol.isEmpty,
                "\(state.rawValue) must have an SF Symbol"
            )
        }
    }

    func testCodableRoundTrip() throws {
        for state in TheaAgentState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(TheaAgentState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testDecodableFromString() throws {
        let json = Data("\"awaitingApproval\"".utf8)
        let decoded = try JSONDecoder().decode(TheaAgentState.self, from: json)
        XCTAssertEqual(decoded, .awaitingApproval)
    }

    func testIdlIsDefaultStartState() {
        // By convention, idle is the starting state
        let state = TheaAgentState.idle
        XCTAssertFalse(state.isTerminal)
        XCTAssertFalse(state.isActive)
    }

    func testPausedIsNeitherActiveNorTerminal() {
        let state = TheaAgentState.paused
        XCTAssertFalse(state.isTerminal)
        XCTAssertFalse(state.isActive)
    }
}

// MARK: - TheaAgentMessage Tests

final class TheaAgentMessageTests: XCTestCase {

    func testDefaultInit() {
        let msg = TheaAgentMessage(role: .user, content: "Hello")
        XCTAssertFalse(msg.id.uuidString.isEmpty)
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertTrue(msg.timestamp.timeIntervalSinceNow < 1)
    }

    func testCustomInit() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let msg = TheaAgentMessage(id: id, role: .system, content: "System prompt", timestamp: date)
        XCTAssertEqual(msg.id, id)
        XCTAssertEqual(msg.role, .system)
        XCTAssertEqual(msg.content, "System prompt")
        XCTAssertEqual(msg.timestamp, date)
    }

    func testRoleRawValues() {
        XCTAssertEqual(TheaAgentMessage.Role.system.rawValue, "system")
        XCTAssertEqual(TheaAgentMessage.Role.user.rawValue, "user")
        XCTAssertEqual(TheaAgentMessage.Role.agent.rawValue, "agent")
    }

    func testEmptyContent() {
        let msg = TheaAgentMessage(role: .agent, content: "")
        XCTAssertTrue(msg.content.isEmpty)
    }

    func testLargeContent() {
        let longText = String(repeating: "x", count: 100_000)
        let msg = TheaAgentMessage(role: .agent, content: longText)
        XCTAssertEqual(msg.content.count, 100_000)
    }

    func testIdentifiable() {
        let msg1 = TheaAgentMessage(role: .user, content: "A")
        let msg2 = TheaAgentMessage(role: .user, content: "A")
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    func testSameIDMeansEqual() {
        let id = UUID()
        let msg1 = TheaAgentMessage(id: id, role: .user, content: "A")
        let msg2 = TheaAgentMessage(id: id, role: .agent, content: "B")
        XCTAssertEqual(msg1.id, msg2.id)
    }
}

// MARK: - TheaAgentArtifact Tests

final class TheaAgentArtifactTests: XCTestCase {

    func testDefaultInit() {
        let artifact = TheaAgentArtifact(title: "Test", type: .code, content: "print(1)")
        XCTAssertFalse(artifact.id.uuidString.isEmpty)
        XCTAssertEqual(artifact.title, "Test")
        XCTAssertEqual(artifact.type, .code)
        XCTAssertEqual(artifact.content, "print(1)")
        XCTAssertTrue(artifact.createdAt.timeIntervalSinceNow < 1)
    }

    func testCustomInit() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 500_000)
        let artifact = TheaAgentArtifact(
            id: id, title: "Plan", type: .plan,
            content: "Step 1: Do X", createdAt: date
        )
        XCTAssertEqual(artifact.id, id)
        XCTAssertEqual(artifact.title, "Plan")
        XCTAssertEqual(artifact.type, .plan)
        XCTAssertEqual(artifact.content, "Step 1: Do X")
        XCTAssertEqual(artifact.createdAt, date)
    }

    func testArtifactTypeRawValues() {
        XCTAssertEqual(TheaAgentArtifact.ArtifactType.code.rawValue, "code")
        XCTAssertEqual(TheaAgentArtifact.ArtifactType.text.rawValue, "text")
        XCTAssertEqual(TheaAgentArtifact.ArtifactType.markdown.rawValue, "markdown")
        XCTAssertEqual(TheaAgentArtifact.ArtifactType.json.rawValue, "json")
        XCTAssertEqual(TheaAgentArtifact.ArtifactType.plan.rawValue, "plan")
        XCTAssertEqual(TheaAgentArtifact.ArtifactType.summary.rawValue, "summary")
    }

    func testAllArtifactTypes() {
        let types: [TheaAgentArtifact.ArtifactType] = [
            .code, .text, .markdown, .json, .plan, .summary
        ]
        XCTAssertEqual(types.count, 6)
        let rawValues = Set(types.map(\.rawValue))
        XCTAssertEqual(rawValues.count, 6, "All artifact type raw values must be unique")
    }

    func testIdentifiable() {
        let a1 = TheaAgentArtifact(title: "A", type: .code, content: "x")
        let a2 = TheaAgentArtifact(title: "A", type: .code, content: "x")
        XCTAssertNotEqual(a1.id, a2.id)
    }

    func testEmptyContent() {
        let artifact = TheaAgentArtifact(title: "Empty", type: .text, content: "")
        XCTAssertTrue(artifact.content.isEmpty)
    }

    func testMarkdownArtifact() {
        let md = "## Heading\n\n- Item 1\n- Item 2"
        let artifact = TheaAgentArtifact(title: "Notes", type: .markdown, content: md)
        XCTAssertTrue(artifact.content.contains("##"))
    }

    func testJSONArtifact() {
        let jsonStr = "{\"key\": \"value\", \"count\": 42}"
        let artifact = TheaAgentArtifact(title: "Config", type: .json, content: jsonStr)
        XCTAssertTrue(artifact.content.contains("key"))
    }
}

// MARK: - TheaContextPressure Tests

final class TheaContextPressureTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(TheaContextPressure.nominal.rawValue, "nominal")
        XCTAssertEqual(TheaContextPressure.elevated.rawValue, "elevated")
        XCTAssertEqual(TheaContextPressure.critical.rawValue, "critical")
        XCTAssertEqual(TheaContextPressure.exceeded.rawValue, "exceeded")
    }

    func testComparableOrdering() {
        XCTAssertTrue(TheaContextPressure.nominal < .elevated)
        XCTAssertTrue(TheaContextPressure.elevated < .critical)
        XCTAssertTrue(TheaContextPressure.critical < .exceeded)
    }

    func testNominalIsLowest() {
        let allLevels: [TheaContextPressure] = [.nominal, .elevated, .critical, .exceeded]
        for level in allLevels where level != .nominal {
            XCTAssertTrue(.nominal < level, "nominal should be less than \(level.rawValue)")
        }
    }

    func testExceededIsHighest() {
        let allLevels: [TheaContextPressure] = [.nominal, .elevated, .critical, .exceeded]
        for level in allLevels where level != .exceeded {
            XCTAssertTrue(level < .exceeded, "\(level.rawValue) should be less than exceeded")
        }
    }

    func testFromUsageNominal() {
        XCTAssertEqual(TheaContextPressure.from(usage: 0.0), .nominal)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.3), .nominal)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.59), .nominal)
    }

    func testFromUsageElevated() {
        XCTAssertEqual(TheaContextPressure.from(usage: 0.6), .elevated)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.7), .elevated)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.79), .elevated)
    }

    func testFromUsageCritical() {
        XCTAssertEqual(TheaContextPressure.from(usage: 0.8), .critical)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.9), .critical)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.94), .critical)
    }

    func testFromUsageExceeded() {
        XCTAssertEqual(TheaContextPressure.from(usage: 0.95), .exceeded)
        XCTAssertEqual(TheaContextPressure.from(usage: 1.0), .exceeded)
        XCTAssertEqual(TheaContextPressure.from(usage: 1.5), .exceeded)
    }

    func testFromUsageBoundaries() {
        // Exact boundaries
        XCTAssertEqual(TheaContextPressure.from(usage: 0.5999), .nominal)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.6), .elevated)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.7999), .elevated)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.8), .critical)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.9499), .critical)
        XCTAssertEqual(TheaContextPressure.from(usage: 0.95), .exceeded)
    }

    func testFromUsageNegative() {
        // Negative values should be nominal
        XCTAssertEqual(TheaContextPressure.from(usage: -0.1), .nominal)
    }

    func testEqualityIsReflexive() {
        let allLevels: [TheaContextPressure] = [.nominal, .elevated, .critical, .exceeded]
        for pressure in allLevels {
            let copy = pressure
            XCTAssertFalse(copy < pressure, "\(pressure.rawValue) should not be less than itself")
            XCTAssertEqual(copy, pressure)
        }
    }
}
