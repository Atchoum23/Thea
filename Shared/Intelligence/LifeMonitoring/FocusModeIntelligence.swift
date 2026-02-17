// FocusModeIntelligence.swift
// THEA - Focus Mode Intelligence & Emergency Communication System
// Created by Claude - February 2026
//
// FULLY AUTONOMOUS Focus mode management:
// - Detects active Focus mode on Mac (reads ~/Library/DoNotDisturb/DB/)
// - Syncs across devices via "Share Across Devices"
// - Auto-creates required Shortcuts on iPhone
// - Language-aware auto-replies
// - WhatsApp status sync via AppleScript
// - Smart caller notification & callback system
// - Emergency contact override
// - Learning & anticipation
//
// CRITICAL: iOS Focus Mode Call Rejection Workaround
// When Focus Mode blocks calls, iOS immediately rejects them at the network level
// (caller hears 3-tone disconnect sound). This breaks "call twice within 3 minutes".
// SOLUTION: Use conditional call forwarding to COMBOX instead of letting iOS reject.
// - When Focus activates: Enable call forwarding to COMBOX (*21*086#)
// - When Focus deactivates: Disable call forwarding (#21#)
// - COMBOX plays Focus-aware greeting with callback instructions
// - SMS sent after voicemail with "call twice" instructions
//
// Additional Enhancements:
// 1. VoIP Call Interception (WhatsApp, Telegram, FaceTime calls via Mac)
// 2. Smart Contact Escalation (3+ messages = urgent)
// 3. Calendar-Aware Auto-Replies
// 4. Location-Based Behavior
// 5. Voice Message Support (transcribe & analyze)
// 6. Group Chat Handling (no spam)
// 7. VIP Mode (personalized responses)
// 8. Learning from Outcomes
//
// Extensions:
// - FocusModeIntelligence+Configuration.swift: Public configuration API
// - FocusModeIntelligence+Monitoring.swift: macOS/iOS Focus mode detection
// - FocusModeIntelligence+EventHandlers.swift: Focus activation/deactivation handlers
// - FocusModeIntelligence+Communication.swift: Incoming call/message handling
// - FocusModeIntelligence+Persistence.swift: Lifecycle, persistence, sync, queries
// - FocusModeIntelligence+AutoReply.swift: Auto-reply, messaging, language/urgency detection
// - FocusModeIntelligence+CallHandling.swift: Call forwarding, VoIP, escalation, voice, groups
// - FocusModeIntelligence+Learning.swift: Urgency assessment, VIP, learning, prediction, advanced

import Foundation
import Intents
import Contacts
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications
#if os(iOS)
import CallKit
#endif

// MARK: - Focus Mode Intelligence Actor

/// Main intelligence system for Focus Mode management.
///
/// Runs as an actor to ensure thread-safe access to all state.
/// Monitors active Focus modes, manages auto-replies, tracks conversations,
/// handles call forwarding, VoIP interception, and cross-device sync.
public actor FocusModeIntelligence {
    // MARK: - Singleton

    /// Shared singleton instance.
    public static let shared = FocusModeIntelligence()

    // MARK: - Properties

    private var isRunning = false
    private var currentFocusMode: FocusModeConfiguration?
    private var focusModes: [String: FocusModeConfiguration] = [:]
    private var globalSettings = FocusModeGlobalSettings()
    private var messageTemplates = LocalizedMessageTemplates()

    // Contact data
    private var contactLanguages: [String: ContactLanguageInfo] = [:]
    private var contactPriorities: [String: Double] = [:] // Learned priority scores
    private var emergencyContacts: Set<String> = []

    // Communication tracking
    private var recentCommunications: [IncomingCommunication] = []
    private var recentAutoReplies: [String: Date] = [:] // Contact -> last reply
    private var pendingCallbacks: [PendingCallback] = []
    private var conversationStates: [String: ConversationState] = [:] // Contact -> state

    // WhatsApp state
    private var previousWhatsAppStatus: String?
    private var whatsAppStatusUpdateTask: Task<Void, Never>?

    // macOS Focus Mode file monitoring
    #if os(macOS)
    private var focusDBMonitor: DispatchSourceFileSystemObject?
    #endif

    // Callbacks
    private var onFocusModeChanged: ((FocusModeConfiguration?) -> Void)?
    private var onAutoReplySent: ((IncomingCommunication, String) -> Void)?
    private var onUrgentDetected: ((IncomingCommunication) -> Void)?
    private var onEmergencyDetected: ((IncomingCommunication) -> Void)?
    private var onSettingsChanged: ((FocusModeGlobalSettings) -> Void)?

    // Call forwarding state
    private var callForwardingEnabled = false

    // VoIP monitoring state
    private var voipMonitoringActive = false
    #if os(macOS)
    private var voipNotificationObserver: NSObjectProtocol?
    #endif

    // Escalation tracking
    private var messageCountTracking: [String: [Date]] = [:] // Contact -> message timestamps
    private var escalationPending: Set<String> = [] // Contacts awaiting urgency confirmation

    // Group chat tracking
    private var groupChatAutoReplies: [String: Int] = [:] // Group ID -> reply count

    // Analytics
    private var currentSessionAnalytics: FocusSessionAnalytics?
    private var historicalAnalytics: [FocusSessionAnalytics] = []

    // Reliability
    private var pendingActions: [PendingAction] = []

    // MARK: - Types

    /// Represents an incoming communication received during Focus mode.
    public struct IncomingCommunication: Identifiable, Sendable {
        public let id: UUID
        public let contactId: String?
        public let contactName: String?
        public let phoneNumber: String?
        public let platform: CommunicationPlatform
        public let type: CommunicationType
        public let timestamp: Date
        public let messageContent: String?
        public let focusModeWhenReceived: String?
        public var autoReplyStatus: AutoReplyStatus
        public var urgencyLevel: UrgencyLevel
        public var languageDetected: String?

        /// The type of communication received.
        public enum CommunicationType: String, Sendable {
            case call = "call"
            case message = "message"
            case missedCall = "missed_call"
            case voicemail = "voicemail"
        }

        /// The status of the auto-reply for this communication.
        public enum AutoReplyStatus: String, Sendable {
            case pending, sent, awaitingResponse, responded, skipped, failed
        }

        /// The assessed urgency level of the communication.
        public enum UrgencyLevel: String, Sendable {
            case unknown, notUrgent, possiblyUrgent, urgent, emergency
        }
    }

    /// Tracks the conversation state machine for a single contact during Focus mode.
    public struct ConversationState: Sendable {
        public let contactId: String
        public var currentStage: Stage
        public var autoRepliesSent: Int
        public var lastMessageTime: Date
        public var awaitingUrgencyResponse: Bool
        public var markedAsUrgent: Bool

        /// The current stage in the auto-reply conversation flow.
        public enum Stage: String, Sendable {
            case initial, askedIfUrgent, confirmedUrgent, callInstructionsSent, resolved
        }
    }

    /// A scheduled callback to return a contact's call or message.
    public struct PendingCallback: Identifiable, Sendable {
        public let id: UUID
        public let contactId: String
        public let phoneNumber: String
        public let platform: CommunicationPlatform
        public let reason: String
        public let scheduledTime: Date
        public var completed: Bool
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Internal Accessors for Extensions

    // --- Global Settings ---
    func getGlobalSettings() -> FocusModeGlobalSettings { globalSettings }
    func setGlobalSettings(_ settings: FocusModeGlobalSettings) { globalSettings = settings }
    func getMessageTemplates() -> LocalizedMessageTemplates { messageTemplates }

    // --- Running State ---
    func getIsRunning() -> Bool { isRunning }
    func setIsRunning(_ running: Bool) { isRunning = running }

    // --- Focus Modes ---
    func getCurrentFocusModeInternal() -> FocusModeConfiguration? { currentFocusMode }
    func setCurrentFocusModeValue(_ mode: FocusModeConfiguration?) { currentFocusMode = mode }
    func getFocusMode(_ id: String) -> FocusModeConfiguration? { focusModes[id] }
    func setFocusMode(_ id: String, mode: FocusModeConfiguration) { focusModes[id] = mode }
    func getAllFocusModesInternal() -> [String: FocusModeConfiguration] { focusModes }
    func setAllFocusModes(_ modes: [String: FocusModeConfiguration]) { focusModes = modes }

    // --- macOS Monitor ---
    #if os(macOS)
    func setFocusDBMonitor(_ monitor: DispatchSourceFileSystemObject?) { focusDBMonitor = monitor }
    func cancelFocusDBMonitor() {
        focusDBMonitor?.cancel()
        focusDBMonitor = nil
    }
    #endif

    // --- WhatsApp ---
    func cancelWhatsAppStatusTask() { whatsAppStatusUpdateTask?.cancel() }
    func getPreviousWhatsAppStatus() -> String? { previousWhatsAppStatus }
    func setPreviousWhatsAppStatus(_ status: String?) { previousWhatsAppStatus = status }

    // --- Auto-Replies ---
    func getRecentAutoReply(for contact: String) -> Date? { recentAutoReplies[contact] }
    func setRecentAutoReply(for contact: String, date: Date) { recentAutoReplies[contact] = date }

    // --- Conversation States ---
    func getConversationState(for contact: String) -> ConversationState? { conversationStates[contact] }
    func setConversationState(for contact: String, state: ConversationState) { conversationStates[contact] = state }
    func getAllConversationStates() -> [String: ConversationState] { conversationStates }

    // --- Callbacks ---
    func getPendingCallbacks() -> [PendingCallback] { pendingCallbacks }

    // --- Contact Languages ---
    func getContactLanguage(_ contactId: String) -> ContactLanguageInfo? { contactLanguages[contactId] }
    func setContactLanguageInfo(_ contactId: String, info: ContactLanguageInfo) { contactLanguages[contactId] = info }
    func getAllContactLanguages() -> [String: ContactLanguageInfo] { contactLanguages }
    func setAllContactLanguages(_ languages: [String: ContactLanguageInfo]) { contactLanguages = languages }

    // --- Emergency Contacts ---
    func getEmergencyContacts() -> Set<String> { emergencyContacts }
    func setEmergencyContacts(_ contacts: Set<String>) { emergencyContacts = contacts }
    func addEmergencyContactInternal(_ contactId: String) {
        emergencyContacts.insert(contactId)
        globalSettings.emergencyContacts.append(contactId)
    }
    func removeEmergencyContactInternal(_ contactId: String) {
        emergencyContacts.remove(contactId)
        globalSettings.emergencyContacts.removeAll { $0 == contactId }
    }

    // --- Call Forwarding ---
    func getCallForwardingEnabled() -> Bool { callForwardingEnabled }
    func setCallForwardingEnabled(_ enabled: Bool) { callForwardingEnabled = enabled }

    // --- VoIP ---
    func getVoIPMonitoringActive() -> Bool { voipMonitoringActive }
    func setVoIPMonitoringActive(_ active: Bool) { voipMonitoringActive = active }
    #if os(macOS)
    func clearVoIPNotificationObserver() {
        if let observer = voipNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            voipNotificationObserver = nil
        }
    }
    #endif

    // --- Escalation ---
    func getMessageCountTracking(for contact: String) -> [Date] { messageCountTracking[contact] ?? [] }
    func setMessageCountTracking(for contact: String, timestamps: [Date]) { messageCountTracking[contact] = timestamps }
    func getAllMessageCountTracking() -> [String: [Date]] { messageCountTracking }
    func getEscalationPending() -> Set<String> { escalationPending }
    func addEscalationPending(_ contact: String) { escalationPending.insert(contact) }
    func removeEscalationPending(_ contact: String) { escalationPending.remove(contact) }

    // --- Group Chat ---
    func getGroupChatAutoReplyCount(for groupId: String) -> Int { groupChatAutoReplies[groupId] ?? 0 }
    func setGroupChatAutoReplyCount(for groupId: String, count: Int) { groupChatAutoReplies[groupId] = count }

    // --- Analytics ---
    func getCurrentSessionAnalytics() -> FocusSessionAnalytics? { currentSessionAnalytics }
    func setCurrentSessionAnalytics(_ analytics: FocusSessionAnalytics?) { currentSessionAnalytics = analytics }
    func getHistoricalAnalytics() -> [FocusSessionAnalytics] { historicalAnalytics }
    func appendHistoricalAnalytics(_ analytics: FocusSessionAnalytics) { historicalAnalytics.append(analytics) }

    // --- Contact Priority ---
    func getContactPriorityValue(_ contactId: String) -> Double { contactPriorities[contactId] ?? 0.5 }
    func setContactPriorityValue(_ contactId: String, priority: Double) { contactPriorities[contactId] = priority }

    // --- Pending Actions ---
    func appendPendingAction(_ action: PendingAction) { pendingActions.append(action) }
    func markPendingActionVerified(_ id: UUID) {
        if let index = pendingActions.firstIndex(where: { $0.id == id }) {
            pendingActions[index].verified = true
        }
    }

    // --- Recent Communications ---
    func getRecentCommunicationsInternal() -> [IncomingCommunication] { recentCommunications }
    func appendRecentCommunication(_ communication: IncomingCommunication) {
        recentCommunications.append(communication)
    }
    func findRecentCommunication(by id: UUID) -> IncomingCommunication? {
        recentCommunications.first { $0.id == id }
    }
    func updateRecentCommunication(_ communication: IncomingCommunication) {
        if let index = recentCommunications.firstIndex(where: { $0.id == communication.id }) {
            recentCommunications[index] = communication
        }
    }

    // --- Event Notification Helpers ---
    func notifyFocusModeChanged(_ mode: FocusModeConfiguration?) {
        onFocusModeChanged?(mode)
    }
    func notifyAutoReplySent(_ communication: IncomingCommunication, _ message: String) {
        onAutoReplySent?(communication, message)
    }
    func notifyUrgentDetected(_ communication: IncomingCommunication) {
        onUrgentDetected?(communication)
    }
    func notifyEmergencyDetected(_ communication: IncomingCommunication) {
        onEmergencyDetected?(communication)
    }
    func notifySettingsChanged(_ settings: FocusModeGlobalSettings) {
        onSettingsChanged?(settings)
    }

    // --- Callback Setters (for Configuration extension) ---
    func setOnFocusModeChanged(_ handler: @escaping @Sendable (FocusModeConfiguration?) -> Void) {
        onFocusModeChanged = handler
    }
    func setOnAutoReplySent(_ handler: @escaping @Sendable (IncomingCommunication, String) -> Void) {
        onAutoReplySent = handler
    }
    func setOnUrgentDetected(_ handler: @escaping @Sendable (IncomingCommunication) -> Void) {
        onUrgentDetected = handler
    }
    func setOnEmergencyDetected(_ handler: @escaping @Sendable (IncomingCommunication) -> Void) {
        onEmergencyDetected = handler
    }
    func setOnSettingsChanged(_ handler: @escaping @Sendable (FocusModeGlobalSettings) -> Void) {
        onSettingsChanged = handler
    }
}
