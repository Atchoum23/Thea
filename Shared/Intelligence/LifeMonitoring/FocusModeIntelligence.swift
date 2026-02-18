// swiftlint:disable file_length
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
// - FocusModeIntelligence+AutoReply.swift: Auto-reply, messaging, language/urgency detection
// - FocusModeIntelligence+CallHandling.swift: Call forwarding, VoIP, escalation, voice, groups
// - FocusModeIntelligence+Learning.swift: Urgency assessment, VIP, learning, prediction, advanced

import Foundation
import Intents
import Contacts
import OSLog
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

// Main intelligence system - runs on Mac, syncs with iPhone
// swiftlint:disable:next type_body_length
public actor FocusModeIntelligence {
    // MARK: - Singleton

    public static let shared = FocusModeIntelligence()

    let logger = Logger(subsystem: "ai.thea.app", category: "FocusMode")

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

        public enum CommunicationType: String, Sendable {
            case call = "call"
            case message = "message"
            case missedCall = "missed_call"
            case voicemail = "voicemail"
        }

        public enum AutoReplyStatus: String, Sendable {
            case pending, sent, awaitingResponse, responded, skipped, failed
        }

        public enum UrgencyLevel: String, Sendable {
            case unknown, notUrgent, possiblyUrgent, urgent, emergency
        }
    }

    public struct ConversationState: Sendable {
        public let contactId: String
        public var currentStage: Stage
        public var autoRepliesSent: Int
        public var lastMessageTime: Date
        public var awaitingUrgencyResponse: Bool
        public var markedAsUrgent: Bool

        public enum Stage: String, Sendable {
            case initial, askedIfUrgent, confirmedUrgent, callInstructionsSent, resolved
        }
    }

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

    func getGlobalSettings() -> FocusModeGlobalSettings { globalSettings }
    func setGlobalSettings(_ settings: FocusModeGlobalSettings) { globalSettings = settings }
    func getMessageTemplates() -> LocalizedMessageTemplates { messageTemplates }

    func getRecentAutoReply(for contact: String) -> Date? { recentAutoReplies[contact] }
    func setRecentAutoReply(for contact: String, date: Date) { recentAutoReplies[contact] = date }

    func getConversationState(for contact: String) -> ConversationState? { conversationStates[contact] }
    func setConversationState(for contact: String, state: ConversationState) { conversationStates[contact] = state }
    func getAllConversationStates() -> [String: ConversationState] { conversationStates }

    func getPendingCallbacks() -> [PendingCallback] { pendingCallbacks }

    func getPreviousWhatsAppStatus() -> String? { previousWhatsAppStatus }
    func setPreviousWhatsAppStatus(_ status: String?) { previousWhatsAppStatus = status }

    func getContactLanguage(_ contactId: String) -> ContactLanguageInfo? { contactLanguages[contactId] }
    func setContactLanguageInfo(_ contactId: String, info: ContactLanguageInfo) { contactLanguages[contactId] = info }

    func getCallForwardingEnabled() -> Bool { callForwardingEnabled }
    func setCallForwardingEnabled(_ enabled: Bool) { callForwardingEnabled = enabled }

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

    func getMessageCountTracking(for contact: String) -> [Date] { messageCountTracking[contact] ?? [] }
    func setMessageCountTracking(for contact: String, timestamps: [Date]) { messageCountTracking[contact] = timestamps }
    func getAllMessageCountTracking() -> [String: [Date]] { messageCountTracking }

    func getEscalationPending() -> Set<String> { escalationPending }
    func addEscalationPending(_ contact: String) { escalationPending.insert(contact) }
    func removeEscalationPending(_ contact: String) { escalationPending.remove(contact) }

    func getGroupChatAutoReplyCount(for groupId: String) -> Int { groupChatAutoReplies[groupId] ?? 0 }
    func setGroupChatAutoReplyCount(for groupId: String, count: Int) { groupChatAutoReplies[groupId] = count }

    func getCurrentSessionAnalytics() -> FocusSessionAnalytics? { currentSessionAnalytics }
    func setCurrentSessionAnalytics(_ analytics: FocusSessionAnalytics?) { currentSessionAnalytics = analytics }
    func getHistoricalAnalytics() -> [FocusSessionAnalytics] { historicalAnalytics }
    func appendHistoricalAnalytics(_ analytics: FocusSessionAnalytics) { historicalAnalytics.append(analytics) }

    func getContactPriorityValue(_ contactId: String) -> Double { contactPriorities[contactId] ?? 0.5 }
    func setContactPriorityValue(_ contactId: String, priority: Double) { contactPriorities[contactId] = priority }

    func appendPendingAction(_ action: PendingAction) { pendingActions.append(action) }
    func markPendingActionVerified(_ id: UUID) {
        if let index = pendingActions.firstIndex(where: { $0.id == id }) {
            pendingActions[index].verified = true
        }
    }

    func getRecentCommunicationsInternal() -> [IncomingCommunication] { recentCommunications }

    func notifyAutoReplySent(_ communication: IncomingCommunication, _ message: String) {
        onAutoReplySent?(communication, message)
    }

    func notifyFocusModeChanged(_ mode: FocusModeConfiguration?) {
        onFocusModeChanged?(mode)
    }

    func setCurrentFocusModeValue(_ mode: FocusModeConfiguration?) {
        currentFocusMode = mode
    }


    // Additional accessors needed by extension files
    func getIsRunning() -> Bool { isRunning }
    func setIsRunning(_ running: Bool) { isRunning = running }

    func getEmergencyContacts() -> Set<String> { emergencyContacts }
    func setEmergencyContacts(_ contacts: Set<String>) { emergencyContacts = contacts }

    func getAllFocusModesInternal() -> [String: FocusModeConfiguration] { focusModes }
    func setAllFocusModes(_ modes: [String: FocusModeConfiguration]) { focusModes = modes }

    func getCurrentFocusModeInternal() -> FocusModeConfiguration? { currentFocusMode }

    func getAllContactLanguages() -> [String: ContactLanguageInfo] { contactLanguages }
    func setAllContactLanguages(_ languages: [String: ContactLanguageInfo]) { contactLanguages = languages }

    #if os(macOS)
    func cancelFocusDBMonitor() {
        focusDBMonitor?.cancel()
        focusDBMonitor = nil
    }
    #else
    func cancelFocusDBMonitor() {}
    #endif

    func cancelWhatsAppStatusTask() {
        whatsAppStatusUpdateTask?.cancel()
        whatsAppStatusUpdateTask = nil
    }

    func appendRecentCommunication(_ comm: IncomingCommunication) {
        recentCommunications.append(comm)
        // Keep last 200
        if recentCommunications.count > 200 {
            recentCommunications.removeFirst(recentCommunications.count - 200)
        }
    }

    func findRecentCommunication(by id: UUID) -> IncomingCommunication? {
        recentCommunications.first { $0.id == id }
    }

    func updateRecentCommunication(_ updated: IncomingCommunication) {
        if let index = recentCommunications.firstIndex(where: { $0.id == updated.id }) {
            recentCommunications[index] = updated
        }
    }

    // MARK: - Notification Helpers (used by +Communication.swift)

    func notifyEmergencyDetected(_ communication: IncomingCommunication) {
        onEmergencyDetected?(communication)
    }

    func notifyUrgentDetected(_ communication: IncomingCommunication) {
        onUrgentDetected?(communication)
    }

    func notifySettingsChanged(_ settings: FocusModeGlobalSettings) {
        onSettingsChanged?(settings)
    }


    // Accessors for Monitoring extension
    #if os(macOS)
    func setFocusDBMonitor(_ monitor: DispatchSourceFileSystemObject?) {
        focusDBMonitor = monitor
    }
    #else
    func setFocusDBMonitor(_ monitor: Any?) {}
    #endif

    func getFocusMode(_ modeId: String) -> FocusModeConfiguration? {
        focusModes[modeId]
    }
    func setFocusMode(_ modeId: String, mode: FocusModeConfiguration) {
        focusModes[modeId] = mode
    }
    func deleteFocusMode(_ modeId: String) {
        focusModes.removeValue(forKey: modeId)
    }

}
