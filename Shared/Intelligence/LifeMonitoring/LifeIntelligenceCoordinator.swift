// LifeIntelligenceCoordinator.swift
// THEA - Central Life Intelligence Coordinator
// Created by Claude - February 2026
//
// THE BRAIN: Coordinates all life monitoring subsystems
// - FocusModeIntelligence: Focus, auto-replies, call handling
// - TaskIntelligence: Tasks, deadlines, reminders
// - RelationshipIntelligence: Contact importance, patterns
// - DeadlineIntelligence: Time-sensitive item tracking
// - HealthIntelligence: Health context
// - CalendarIntelligence: Schedule awareness
//
// Provides unified decision-making with full context.

import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - Life Intelligence Coordinator

public actor LifeIntelligenceCoordinator {
    public static let shared = LifeIntelligenceCoordinator()

    // MARK: - Subsystems

    private let focusIntelligence = FocusModeIntelligence.shared
    private let taskIntelligence = TaskIntelligence.shared
    private let relationshipIntelligence = RelationshipIntelligence.shared

    // MARK: - State

    private var isRunning = false
    private var currentContext = LifeContext()
    private var pendingDecisions: [PendingDecision] = []
    private var dailyDigest: DailyDigest?

    // MARK: - Types

    public struct LifeContext: Sendable {
        public var currentFocusMode: String?
        public var isFocusModeActive: Bool = false
        public var currentActivity: UserActivity = .available
        public var currentLocation: String?
        public var isInMeeting: Bool = false
        public var urgentTasksCount: Int = 0
        public var overdueTasksCount: Int = 0
        public var unreadMessagesCount: Int = 0
        public var missedCallsCount: Int = 0
        public var batteryLevel: Int = 100
        public var isConnectedToNetwork: Bool = true
        public var lastUpdated = Date()

        public enum UserActivity: String, Sendable {
            case sleeping, exercising, driving, inMeeting, working, relaxing, available
        }
    }

    public struct PendingDecision: Identifiable, Sendable {
        public let id: UUID
        public let type: DecisionType
        public let contactId: String?
        public let content: String
        public let urgencyScore: Double
        public let timestamp: Date
        public var resolution: Resolution?

        public enum DecisionType: String, Sendable {
            case respondToMessage
            case returnCall
            case completeTask
            case followUp
            case scheduleEvent
        }

        public enum Resolution: String, Sendable {
            case handled, deferred, ignored, delegated
        }
    }

    public struct DailyDigest: Sendable {
        public let date: Date
        public var focusTimeMinutes: Int = 0
        public var messagesReceived: Int = 0
        public var messagesSent: Int = 0
        public var callsMade: Int = 0
        public var callsMissed: Int = 0
        public var tasksCompleted: Int = 0
        public var tasksCreated: Int = 0
        public var overdueTasksAtEndOfDay: Int = 0
        public var topContacts: [String] = []
        public var productivityScore: Double = 0.5
        public var insights: [String] = []
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        print("[LifeCoordinator] Starting all intelligence subsystems...")

        // Start all subsystems
        await focusIntelligence.start()
        await taskIntelligence.loadTasks()
        _ = await taskIntelligence.requestAccess()
        await taskIntelligence.startDeadlineMonitoring()
        await relationshipIntelligence.loadData()

        // Configure cross-system callbacks
        await configureCallbacks()

        // Start periodic context updates
        Task {
            await periodicContextUpdate()
        }

        // Start daily digest generation
        Task {
            await generateDailyDigestPeriodically()
        }

        print("[LifeCoordinator] ✓ All systems online")
    }

    public func stop() async {
        isRunning = false
        await focusIntelligence.stop()
        print("[LifeCoordinator] All systems stopped")
    }

    // MARK: - Callback Configuration

    private func configureCallbacks() async {
        // Task callbacks
        await taskIntelligence.configure(
            onTaskDueSoon: { [weak self] task, timeRemaining in
                Task {
                    await self?.handleTaskDueSoon(task, timeRemaining: timeRemaining)
                }
            },
            onTaskOverdue: { [weak self] task in
                Task {
                    await self?.handleTaskOverdue(task)
                }
            },
            onUrgentTaskDetected: { [weak self] task in
                Task {
                    await self?.handleUrgentTask(task)
                }
            }
        )

        // Relationship callbacks
        await relationshipIntelligence.configure(
            onRelationshipDecay: { [weak self] relationship in
                Task {
                    await self?.handleRelationshipDecay(relationship)
                }
            },
            onFollowUpSuggested: { [weak self] relationship, reason in
                Task {
                    await self?.handleFollowUpSuggestion(relationship, reason: reason)
                }
            },
            onNewContactDetected: { relationship in
                print("[LifeCoordinator] New contact: \(relationship.name)")
            }
        )
    }

    // MARK: - Unified Decision Making

    /// Make a unified decision about how to handle incoming communication
    public func decideCommunicationResponse(
        contactId: String?,
        contactName: String?,
        messageContent: String,
        platform: String,
        isCall: Bool
    ) async -> CommunicationDecision {
        // Gather all context
        var urgencyScore: Double = 0.3 // Base

        // 1. Check relationship context
        if let cId = contactId {
            let relationship = await relationshipIntelligence.getRelationship(for: cId)
            let relationshipBoost = await relationshipIntelligence.getUrgencyBoost(for: cId)
            urgencyScore += relationshipBoost

            // VIP contacts get special treatment
            if relationship?.tier == .vip {
                return CommunicationDecision(
                    action: .notifyUserImmediately,
                    reason: "VIP contact",
                    autoReply: nil,
                    urgencyScore: 0.9
                )
            }
        }

        // 2. Check task context - is this related to a deadline?
        let urgentTasks = await taskIntelligence.getUrgentTasks()
        for task in urgentTasks {
            if task.relatedContactIds.contains(contactId ?? "") {
                urgencyScore += 0.2
                break
            }
        }

        // 3. Check Focus Mode context
        let currentFocus = await focusIntelligence.getCurrentFocusMode()
        let isFocusActive = currentFocus != nil

        // 4. Analyze message content for urgency
        let contentUrgency = analyzeContentUrgency(messageContent)
        urgencyScore += contentUrgency

        // 5. Time context
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 7 {
            // Late night/early morning = probably more urgent if reaching out
            urgencyScore += 0.1
        }

        // Make decision
        let clampedScore = min(1.0, max(0.0, urgencyScore))

        if clampedScore > 0.8 {
            return CommunicationDecision(
                action: .notifyUserImmediately,
                reason: "High urgency detected",
                autoReply: nil,
                urgencyScore: clampedScore
            )
        } else if isFocusActive && clampedScore < 0.5 {
            return CommunicationDecision(
                action: .autoReplyAndDefer,
                reason: "Focus Mode active, low urgency",
                autoReply: generateAutoReply(for: contactId, platform: platform),
                urgencyScore: clampedScore
            )
        } else if clampedScore > 0.5 {
            return CommunicationDecision(
                action: .notifyUserSoon,
                reason: "Moderate urgency",
                autoReply: nil,
                urgencyScore: clampedScore
            )
        } else {
            return CommunicationDecision(
                action: .silentlyQueue,
                reason: "Low priority",
                autoReply: nil,
                urgencyScore: clampedScore
            )
        }
    }

    public struct CommunicationDecision: Sendable {
        public let action: Action
        public let reason: String
        public let autoReply: String?
        public let urgencyScore: Double

        public enum Action: String, Sendable {
            case notifyUserImmediately // Break through Focus if needed
            case notifyUserSoon // Next time they check
            case autoReplyAndDefer // Send auto-reply, add to queue
            case silentlyQueue // Just log it
        }
    }

    private func analyzeContentUrgency(_ content: String) -> Double {
        let lowercased = content.lowercased()
        var score: Double = 0

        let urgentWords = ["urgent", "emergency", "asap", "immediately", "help", "critical", "deadline"]
        for word in urgentWords {
            if lowercased.contains(word) {
                score += 0.2
            }
        }

        return min(0.5, score)
    }

    private func generateAutoReply(for contactId: String?, platform: String) -> String {
        // Would be more sophisticated with templates
        "I'm currently focused on something. I'll get back to you soon."
    }

    // MARK: - Cross-System Event Handlers

    private func handleTaskDueSoon(_ task: IntelligenceTask, timeRemaining: TimeInterval) async {
        let minutes = Int(timeRemaining / 60)
        print("[LifeCoordinator] Task due soon: \(task.title) in \(minutes) minutes")

        // Check if we should interrupt Focus Mode
        if task.blocksFocusMode && task.urgencyScore > 0.7 {
            await sendNotification(
                title: "⏰ Task Due Soon",
                body: "\(task.title) is due in \(minutes) minutes",
                priority: .high
            )
        }
    }

    private func handleTaskOverdue(_ task: IntelligenceTask) async {
        print("[LifeCoordinator] Task overdue: \(task.title)")

        await sendNotification(
            title: "⚠️ Overdue Task",
            body: task.title,
            priority: .high
        )

        currentContext.overdueTasksCount += 1
    }

    private func handleUrgentTask(_ task: IntelligenceTask) async {
        print("[LifeCoordinator] Urgent task detected: \(task.title)")
        currentContext.urgentTasksCount += 1
    }

    private func handleRelationshipDecay(_ relationship: ContactRelationship) async {
        print("[LifeCoordinator] Relationship decay: \(relationship.name)")

        // Only notify for inner circle and above
        if relationship.tier == .vip || relationship.tier == .inner {
            await sendNotification(
                title: "💭 Reconnect Suggestion",
                body: "You haven't talked to \(relationship.name) in a while",
                priority: .low
            )
        }
    }

    private func handleFollowUpSuggestion(_ relationship: ContactRelationship, reason: String) async {
        print("[LifeCoordinator] Follow-up suggested for \(relationship.name): \(reason)")
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String, priority: NotificationPriority) async {
        #if canImport(UserNotifications) && !os(macOS)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        switch priority {
        case .high:
            content.interruptionLevel = .timeSensitive
        case .medium:
            content.interruptionLevel = .active
        case .low:
            content.interruptionLevel = .passive
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
        #endif

        print("[Notification] \(priority): \(title) - \(body)")
    }

    private enum NotificationPriority {
        case high, medium, low
    }

    // MARK: - Context Updates

    private func periodicContextUpdate() async {
        while isRunning {
            try? await Task.sleep(for: .seconds(60))

            // Update context
            currentContext.urgentTasksCount = await taskIntelligence.getUrgentTasks().count
            currentContext.overdueTasksCount = await taskIntelligence.getOverdueTasks().count

            if let focusMode = await focusIntelligence.getCurrentFocusMode() {
                currentContext.isFocusModeActive = true
                currentContext.currentFocusMode = focusMode.name
            } else {
                currentContext.isFocusModeActive = false
                currentContext.currentFocusMode = nil
            }

            currentContext.lastUpdated = Date()
        }
    }

    // MARK: - Daily Digest

    private func generateDailyDigestPeriodically() async {
        while isRunning {
            // Wait until end of day (11 PM)
            let now = Date()
            let calendar = Calendar.current
            var endOfDay = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!

            if now >= endOfDay {
                endOfDay = calendar.date(byAdding: .day, value: 1, to: endOfDay)!
            }

            let timeUntilDigest = endOfDay.timeIntervalSince(now)
            try? await Task.sleep(for: .seconds(timeUntilDigest))

            await generateDailyDigest()
        }
    }

    private func generateDailyDigest() async {
        var digest = DailyDigest(date: Date())

        // Gather stats from all subsystems
        let tasks = await taskIntelligence.getAllActiveTasks()
        digest.overdueTasksAtEndOfDay = tasks.filter { $0.dueDate ?? .distantFuture < Date() }.count

        // Get recent contacts
        let recentContacts = await relationshipIntelligence.getRecentlyContactedPeople(days: 1)
        digest.topContacts = recentContacts.prefix(5).map { $0.name }

        // Generate insights
        if digest.overdueTasksAtEndOfDay > 0 {
            digest.insights.append("You have \(digest.overdueTasksAtEndOfDay) overdue tasks")
        }

        if let focusTime = calculateFocusTimeToday() {
            digest.focusTimeMinutes = focusTime
            if focusTime > 120 {
                digest.insights.append("Great job! You had \(focusTime / 60) hours of focused time today")
            }
        }

        // Calculate productivity score
        digest.productivityScore = calculateProductivityScore(for: digest)

        dailyDigest = digest

        // Send digest notification
        await sendDailyDigestNotification(digest)
    }

    private func calculateFocusTimeToday() -> Int? {
        // Would track Focus Mode duration
        nil
    }

    private func calculateProductivityScore(for digest: DailyDigest) -> Double {
        var score: Double = 0.5

        // More completed tasks = higher score
        if digest.tasksCompleted > 5 { score += 0.2 } else if digest.tasksCompleted > 2 { score += 0.1 }

        // Fewer overdue = higher score
        if digest.overdueTasksAtEndOfDay == 0 { score += 0.2 } else if digest.overdueTasksAtEndOfDay > 5 { score -= 0.2 }

        // More focus time = higher score
        if digest.focusTimeMinutes > 180 { score += 0.2 } else if digest.focusTimeMinutes > 60 { score += 0.1 }

        return min(1.0, max(0.0, score))
    }

    private func sendDailyDigestNotification(_ digest: DailyDigest) async {
        let scoreEmoji = digest.productivityScore > 0.7 ? "🌟" : digest.productivityScore > 0.4 ? "👍" : "💪"

        await sendNotification(
            title: "\(scoreEmoji) Daily Digest",
            body: "Tasks: \(digest.tasksCompleted) done, \(digest.overdueTasksAtEndOfDay) overdue",
            priority: .low
        )
    }

    // MARK: - Public Queries

    public func getCurrentContext() -> LifeContext {
        currentContext
    }

    public func getDailyDigest() -> DailyDigest? {
        dailyDigest
    }

    public func getUrgentItems() async -> UrgentItemsSummary {
        let urgentTasks = await taskIntelligence.getUrgentTasks()
        let overdueTasks = await taskIntelligence.getOverdueTasks()
        let recentComms = await focusIntelligence.getRecentCommunications(limit: 10)
        let urgentComms = recentComms.filter { $0.urgencyLevel == .urgent || $0.urgencyLevel == .emergency }

        return UrgentItemsSummary(
            urgentTasks: urgentTasks,
            overdueTasks: overdueTasks,
            urgentCommunications: urgentComms,
            totalUrgentCount: urgentTasks.count + urgentComms.count
        )
    }

    public struct UrgentItemsSummary: Sendable {
        public let urgentTasks: [IntelligenceTask]
        public let overdueTasks: [IntelligenceTask]
        public let urgentCommunications: [FocusModeIntelligence.IncomingCommunication]
        public let totalUrgentCount: Int
    }

    // MARK: - Quick Actions

    /// Quick add a task from voice or text
    public func quickAddTask(_ naturalLanguage: String) async -> IntelligenceTask {
        let task = await taskIntelligence.parseNaturalLanguage(naturalLanguage)
        return await taskIntelligence.addTask(task)
    }

    /// Log a communication event
    func logCommunication(
        contactId: String,
        contactName: String,
        direction: RelationshipIntelligence.CommunicationEvent.Direction,
        type: RelationshipIntelligence.CommunicationEvent.EventType,
        platform: String
    ) async {
        await relationshipIntelligence.logCommunication(
            contactId: contactId,
            contactName: contactName,
            direction: direction,
            type: type,
            platform: platform
        )
    }

    /// Get today's priorities
    public func getTodaysPriorities() async -> TodaysPriorities {
        let tasksDueToday = await taskIntelligence.getTasksDueToday()
        let overdueTasks = await taskIntelligence.getOverdueTasks()
        let reconnectSuggestions = await relationshipIntelligence.getPeopleToReconnectWith()

        return TodaysPriorities(
            tasksDueToday: tasksDueToday,
            overdueTasks: overdueTasks,
            reconnectSuggestions: reconnectSuggestions,
            focusSuggestion: await focusIntelligence.predictFocusModeActivation()
        )
    }

    public struct TodaysPriorities: Sendable {
        public let tasksDueToday: [IntelligenceTask]
        public let overdueTasks: [IntelligenceTask]
        public let reconnectSuggestions: [ContactRelationship]
        public let focusSuggestion: FocusModeIntelligence.FocusPrediction?
    }
}
