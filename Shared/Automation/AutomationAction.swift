// AutomationAction.swift
// Thea
//
// Data types representing automation actions that Thea can execute
// during browser/screen automation workflows. Used by
// BrowserAutomationOrchestrator to track and execute AI-decided actions.

#if os(macOS)

    import Foundation

    // MARK: - Automation Action

    /// A single action to be executed during an automation workflow.
    public struct AutomationAction: Identifiable, Sendable {
        public let id: UUID
        public let type: ActionType
        public let description: String
        public let confidence: Double
        public let timestamp: Date
        public var result: AutomationActionResult?

        public init(
            type: ActionType,
            description: String,
            confidence: Double = 1.0
        ) {
            self.id = UUID()
            self.type = type
            self.description = description
            self.confidence = confidence
            self.timestamp = Date()
            self.result = nil
        }

        /// The action completed successfully
        public var succeeded: Bool {
            result?.success ?? false
        }

        /// Duration of execution (nil if not yet completed)
        public var duration: TimeInterval? {
            guard let result else { return nil }
            return result.timestamp.timeIntervalSince(timestamp)
        }
    }

    // MARK: - Action Type

    /// Types of actions the automation system can execute.
    public enum ActionType: Sendable {
        // Mouse actions
        case click(x: Int, y: Int)
        case doubleClick(x: Int, y: Int)
        case rightClick(x: Int, y: Int)

        // Keyboard actions
        case type(text: String)
        case keyCombo(key: String, modifiers: [String])

        // Scroll
        case scroll(direction: ScrollDirection, amount: Int)

        // Browser-specific (WKWebView)
        case navigate(url: String)
        case jsExecute(script: String)

        // Control flow
        case wait(seconds: Double)
        case screenshot
        case done(reason: String)

        /// Human-readable description of the action
        public var displayName: String {
            switch self {
            case let .click(x, y): return "Click at (\(x), \(y))"
            case let .doubleClick(x, y): return "Double-click at (\(x), \(y))"
            case let .rightClick(x, y): return "Right-click at (\(x), \(y))"
            case let .type(text): return "Type: \(text.prefix(30))\(text.count > 30 ? "..." : "")"
            case let .keyCombo(key, mods): return "Key: \(mods.joined(separator: "+"))+\(key)"
            case let .scroll(dir, amt): return "Scroll \(dir.rawValue) x\(amt)"
            case let .navigate(url): return "Navigate: \(url.prefix(40))"
            case .jsExecute: return "Execute JavaScript"
            case let .wait(secs): return "Wait \(String(format: "%.1f", secs))s"
            case .screenshot: return "Capture screenshot"
            case let .done(reason): return "Done: \(reason)"
            }
        }
    }

    // MARK: - Scroll Direction

    public enum ScrollDirection: String, Sendable {
        case up
        case down
        case left
        case right
    }

    // MARK: - Action Result

    /// Result of executing an automation action.
    public struct AutomationActionResult: Sendable {
        public let success: Bool
        public let message: String?
        public let timestamp: Date
        public let screenshotData: Data?

        public init(
            success: Bool,
            message: String? = nil,
            screenshotData: Data? = nil
        ) {
            self.success = success
            self.message = message
            self.timestamp = Date()
            self.screenshotData = screenshotData
        }
    }

    // MARK: - Action Batch

    /// A batch of related actions executed as a group.
    public struct ActionBatch: Identifiable, Sendable {
        public let id: UUID
        public let description: String
        public var actions: [AutomationAction]
        public let createdAt: Date

        public init(description: String, actions: [AutomationAction] = []) {
            self.id = UUID()
            self.description = description
            self.actions = actions
            self.createdAt = Date()
        }

        public var completedCount: Int {
            actions.filter { $0.result != nil }.count
        }

        public var succeededCount: Int {
            actions.filter { $0.succeeded }.count
        }

        public var isComplete: Bool {
            actions.allSatisfy { $0.result != nil }
        }
    }

#endif
