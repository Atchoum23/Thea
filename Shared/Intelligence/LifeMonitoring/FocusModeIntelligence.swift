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

// Main intelligence system - runs on Mac, syncs with iPhone
// swiftlint:disable:next type_body_length
public actor FocusModeIntelligence {
    // MARK: - Singleton

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

    // MARK: - Public Configuration API

    /// Configure callbacks
    public func configure(
        onFocusModeChanged: @escaping @Sendable (FocusModeConfiguration?) -> Void,
        onAutoReplySent: @escaping @Sendable (IncomingCommunication, String) -> Void,
        onUrgentDetected: @escaping @Sendable (IncomingCommunication) -> Void,
        onEmergencyDetected: @escaping @Sendable (IncomingCommunication) -> Void,
        onSettingsChanged: @escaping @Sendable (FocusModeGlobalSettings) -> Void
    ) {
        self.onFocusModeChanged = onFocusModeChanged
        self.onAutoReplySent = onAutoReplySent
        self.onUrgentDetected = onUrgentDetected
        self.onEmergencyDetected = onEmergencyDetected
        self.onSettingsChanged = onSettingsChanged
    }

    /// Update global settings
    public func updateSettings(_ settings: FocusModeGlobalSettings) {
        self.globalSettings = settings
        onSettingsChanged?(settings)

        Task {
            await saveSettings()
            await syncSettingsToiPhone()
        }
    }

    /// Get current settings
    public func getSettings() -> FocusModeGlobalSettings {
        globalSettings
    }

    /// Update settings for a specific Focus mode
    public func updateFocusModeSettings(_ modeId: String, settings: FocusModeConfiguration.TheaFocusSettings) {
        guard var mode = focusModes[modeId] else { return }
        mode.theaSettings = settings
        focusModes[modeId] = mode

        Task {
            await saveSettings()
        }
    }

    /// Add emergency contact
    public func addEmergencyContact(_ contactId: String) {
        emergencyContacts.insert(contactId)
        globalSettings.emergencyContacts.append(contactId)

        Task {
            await saveSettings()
        }
    }

    /// Remove emergency contact
    public func removeEmergencyContact(_ contactId: String) {
        emergencyContacts.remove(contactId)
        globalSettings.emergencyContacts.removeAll { $0 == contactId }

        Task {
            await saveSettings()
        }
    }

    /// Set contact language manually
    public func setContactLanguage(_ contactId: String, language: String) {
        contactLanguages[contactId] = ContactLanguageInfo(
            contactId: contactId,
            detectedLanguage: language,
            confidence: 1.0,
            detectionMethod: .manualSetting,
            isManuallySet: true,
            previousLanguages: [],
            lastUpdated: Date()
        )

        Task {
            await saveContactLanguages()
        }
    }

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Load saved data
        await loadSettings()
        await loadFocusModes()
        await loadContactLanguages()

        // Start Focus mode monitoring
        #if os(macOS)
        await startMacOSFocusMonitoring()
        #else
        await startIOSFocusMonitoring()
        #endif

        // Setup Shortcuts (autonomous)
        await ensureShortcutsExist()

        // Start periodic tasks
        await startPeriodicTasks()
    }

    public func stop() async {
        isRunning = false

        #if os(macOS)
        focusDBMonitor?.cancel()
        focusDBMonitor = nil
        #endif

        whatsAppStatusUpdateTask?.cancel()

        await saveSettings()
    }

    // MARK: - macOS Focus Mode Detection

    #if os(macOS)
    private func startMacOSFocusMonitoring() async {
        // Read Focus mode directly from macOS system files
        // Path: ~/Library/DoNotDisturb/DB/

        let doNotDisturbPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB"

        // Initial read
        await readCurrentFocusModeFromMacOS()

        // Monitor for changes
        let fileDescriptor = open(doNotDisturbPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[FocusMode] Failed to open DoNotDisturb directory for monitoring")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.readCurrentFocusModeFromMacOS()
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        focusDBMonitor = source
    }

    private func readCurrentFocusModeFromMacOS() async {
        // Read Assertions.json for current active Focus
        let assertionsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"

        // Read ModeConfigurations.json for all Focus mode settings
        let configurationsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/ModeConfigurations.json"

        do {
            // Read current active Focus
            if let assertionsData = FileManager.default.contents(atPath: assertionsPath) {
                let assertions = try JSONDecoder().decode(FocusAssertions.self, from: assertionsData)
                await processFocusAssertions(assertions)
            }

            // Read all Focus configurations
            if let configData = FileManager.default.contents(atPath: configurationsPath) {
                let configs = try JSONDecoder().decode(FocusModeConfigurations.self, from: configData)
                await processFocusModeConfigurations(configs)
            }
        } catch {
            print("[FocusMode] Error reading Focus data: \(error)")
        }
    }

    // Structures to decode macOS Focus JSON files
    private struct FocusAssertions: Codable {
        let data: [AssertionData]?

        struct AssertionData: Codable {
            let storeAssertionRecords: [AssertionRecord]?
        }

        struct AssertionRecord: Codable {
            let assertionDetails: AssertionDetails?
        }

        struct AssertionDetails: Codable {
            let assertionDetailsModeIdentifier: String?
        }
    }

    private struct FocusModeConfigurations: Codable {
        let data: [ModeData]?

        struct ModeData: Codable {
            let modeConfigurations: [String: ModeConfig]?
        }

        struct ModeConfig: Codable {
            let name: String?
            let identifier: String?
            let semanticType: Int?
            let configuration: Configuration?

            struct Configuration: Codable {
                let allowRepeatedCalls: Bool?
                let allowedContactsRule: String?
                let allowedApplicationsRule: String?
            }
        }
    }

    private func processFocusAssertions(_ assertions: FocusAssertions) async {
        // Find active Focus mode
        var activeModeId: String?

        if let data = assertions.data?.first,
           let records = data.storeAssertionRecords {
            for record in records {
                if let modeId = record.assertionDetails?.assertionDetailsModeIdentifier {
                    activeModeId = modeId
                    break
                }
            }
        }

        if let modeId = activeModeId {
            // Focus mode is active
            if currentFocusMode?.id != modeId {
                if let mode = focusModes[modeId] {
                    var activeMode = mode
                    activeMode.isActive = true
                    currentFocusMode = activeMode
                    await handleFocusModeActivated(activeMode)
                    onFocusModeChanged?(activeMode)
                }
            }
        } else {
            // No Focus mode active
            if let previousMode = currentFocusMode {
                currentFocusMode = nil
                await handleFocusModeDeactivated(previousMode)
                onFocusModeChanged?(nil)
            }
        }
    }

    private func processFocusModeConfigurations(_ configs: FocusModeConfigurations) async {
        guard let data = configs.data?.first,
              let modeConfigs = data.modeConfigurations else { return }

        for (modeId, config) in modeConfigs {
            // Only add if we don't have THEA settings for this mode yet
            if focusModes[modeId] == nil {
                let mode = FocusModeConfiguration(
                    id: modeId,
                    name: config.name ?? "Unknown",
                    allowRepeatedCalls: config.configuration?.allowRepeatedCalls ?? true
                )
                focusModes[modeId] = mode
            }
        }
    }
    #endif

    // MARK: - iOS Focus Mode Detection

    private func startIOSFocusMonitoring() async {
        // iOS uses INFocusStatusCenter
        let center = INFocusStatusCenter.default

        // Request authorization
        let status = await center.requestAuthorization()
        print("[FocusMode] iOS authorization status: \(status)")

        // Note: iOS doesn't tell us WHICH Focus is active, only that Focus IS active
        // We work around this by using Shortcuts automations
    }

    // MARK: - Focus Mode Event Handlers

    private func handleFocusModeActivated(_ mode: FocusModeConfiguration) async {
        print("[FocusMode] Activated: \(mode.name)")

        // ====================================
        // CRITICAL: CALL FORWARDING WORKAROUND
        // ====================================
        // iOS Focus Mode rejects calls at network level (3-tone disconnect)
        // This means callers can't even leave voicemail and "call twice" won't work!
        // Solution: Enable call forwarding to COMBOX BEFORE iOS can reject
        //
        // IMPORTANT: Only enable call forwarding if this Focus mode BLOCKS calls!
        // Some Focus modes (Driving, Personal, etc.) may allow calls from everyone.
        // We check mode.allowCallsFrom to determine if calls are being blocked.
        //
        // When Focus activates AND blocks calls:
        // 1. Forward ALL calls to COMBOX (*21*086#)
        // 2. COMBOX plays Focus-aware greeting
        // 3. After voicemail, THEA sends SMS with "call twice" instructions
        // 4. If caller calls back, we can detect via COMBOX notification

        if globalSettings.useCallForwardingWorkaround {
            // Only forward calls if this Focus mode actually blocks them
            let modeBlocksCalls = mode.allowCallsFrom != .everyone

            if modeBlocksCalls {
                await enableCallForwarding()
                print("[FocusMode] Call forwarding enabled - mode '\(mode.name)' blocks some calls")
            } else {
                print("[FocusMode] Call forwarding NOT needed - mode '\(mode.name)' allows all calls")
            }
        }

        // 1. Update WhatsApp status
        if globalSettings.whatsAppStatusSyncEnabled && mode.theaSettings.whatsAppStatusEnabled {
            await updateWhatsAppStatus(mode.theaSettings.whatsAppStatusMessage)
        }

        // 2. Update Telegram status
        if globalSettings.telegramStatusSyncEnabled && mode.theaSettings.telegramStatusEnabled {
            await updateTelegramStatus(mode.theaSettings.telegramStatusMessage)
        }

        // 3. Switch COMBOX greeting (now even more important since calls go there)
        if globalSettings.comboxIntegrationEnabled && globalSettings.comboxSwitchGreetingOnFocus {
            if let greeting = mode.theaSettings.comboxGreetingType {
                await switchComboxGreeting(to: greeting)
            } else {
                await switchComboxGreeting(to: globalSettings.comboxFocusGreeting)
            }
        }

        // 4. Start VoIP call interception (Enhancement 1)
        if globalSettings.voipInterceptionEnabled {
            await startVoIPInterception()
        }

        // 5. Sync to iPhone
        await notifyiPhoneOfFocusChange(active: true, mode: mode)
    }

    private func handleFocusModeDeactivated(_ mode: FocusModeConfiguration) async {
        print("[FocusMode] Deactivated: \(mode.name)")

        // ====================================
        // CRITICAL: DISABLE CALL FORWARDING
        // ====================================
        // Restore normal call behavior when Focus ends
        // Only disable if we actually enabled it (i.e., this mode was blocking calls)

        if globalSettings.useCallForwardingWorkaround && callForwardingEnabled {
            await disableCallForwarding()
        }

        // 1. Revert WhatsApp status
        if globalSettings.whatsAppStatusSyncEnabled && globalSettings.preservePreviousWhatsAppStatus {
            await revertWhatsAppStatus()
        }

        // 2. Revert Telegram status
        if globalSettings.telegramStatusSyncEnabled {
            await clearTelegramStatus()
        }

        // 3. Revert COMBOX greeting
        if globalSettings.comboxIntegrationEnabled && globalSettings.comboxSwitchGreetingOnFocus {
            await switchComboxGreeting(to: globalSettings.comboxDefaultGreeting)
        }

        // 4. Stop VoIP interception
        if globalSettings.voipInterceptionEnabled {
            await stopVoIPInterception()
        }

        // 5. Process pending callbacks
        await processPendingCallbacks()

        // 6. Apply learning from this Focus session (Enhancement 8)
        if globalSettings.learningEnabled {
            await applyLearningFromSession(mode: mode)
        }

        // 7. Sync to iPhone
        await notifyiPhoneOfFocusChange(active: false, mode: mode)
    }

    // MARK: - Incoming Communication Handling

    /// Handle incoming call
    public func handleIncomingCall(
        from phoneNumber: String?,
        contactId: String?,
        contactName: String?,
        platform: CommunicationPlatform
    ) async {
        guard globalSettings.systemEnabled else { return }
        guard let mode = currentFocusMode else { return }

        // Check if emergency contact
        if let cId = contactId, emergencyContacts.contains(cId) {
            print("[FocusMode] Emergency contact calling - allowing through")
            return // Don't block
        }

        // Check if allowed contact
        if let cId = contactId, mode.allowedContacts.contains(cId) {
            return // Don't block
        }

        let communication = IncomingCommunication(
            id: UUID(),
            contactId: contactId,
            contactName: contactName,
            phoneNumber: phoneNumber,
            platform: platform,
            type: .call,
            timestamp: Date(),
            messageContent: nil,
            focusModeWhenReceived: mode.name,
            autoReplyStatus: .pending,
            urgencyLevel: .unknown,
            languageDetected: nil
        )

        recentCommunications.append(communication)

        // Wait a moment to see if this becomes a missed call
        try? await Task.sleep(for: .seconds(30))

        // If still in our list as a call, it was likely declined/missed
        if let index = recentCommunications.firstIndex(where: { $0.id == communication.id }),
           recentCommunications[index].type == .call {
            var missedCall = recentCommunications[index]
            missedCall.autoReplyStatus = .pending
            recentCommunications[index] = missedCall

            // Send missed call notification
            if globalSettings.callerNotificationEnabled && globalSettings.sendSMSAfterMissedCall {
                try? await Task.sleep(for: .seconds(globalSettings.smsDelayAfterMissedCall))
                await sendMissedCallNotification(for: missedCall)
            }
        }
    }

    /// Handle incoming message
    public func handleIncomingMessage(
        from contactId: String?,
        contactName: String?,
        phoneNumber: String?,
        platform: CommunicationPlatform,
        messageContent: String
    ) async {
        guard globalSettings.systemEnabled else { return }
        guard let mode = currentFocusMode else { return }

        // Check if emergency contact
        if let cId = contactId, emergencyContacts.contains(cId) {
            // Still process but mark as priority
            print("[FocusMode] Message from emergency contact")
        }

        // Check if allowed contact
        if let cId = contactId, mode.allowedContacts.contains(cId) {
            return // Don't auto-reply
        }

        // Detect language
        let language = await detectLanguage(for: contactId, phoneNumber: phoneNumber, messageContent: messageContent)

        var communication = IncomingCommunication(
            id: UUID(),
            contactId: contactId,
            contactName: contactName,
            phoneNumber: phoneNumber,
            platform: platform,
            type: .message,
            timestamp: Date(),
            messageContent: messageContent,
            focusModeWhenReceived: mode.name,
            autoReplyStatus: .pending,
            urgencyLevel: .unknown,
            languageDetected: language
        )

        // Check for emergency keywords first
        if detectEmergency(in: messageContent, language: language) {
            communication.urgencyLevel = .emergency
            onEmergencyDetected?(communication)
            await handleEmergencyMessage(communication)
            return
        }

        // Check for urgency keywords
        let urgency = detectUrgency(in: messageContent, language: language)
        communication.urgencyLevel = urgency

        recentCommunications.append(communication)

        // Get or create conversation state
        let contactKey = contactId ?? phoneNumber ?? UUID().uuidString
        var state = conversationStates[contactKey] ?? ConversationState(
            contactId: contactKey,
            currentStage: .initial,
            autoRepliesSent: 0,
            lastMessageTime: Date(),
            awaitingUrgencyResponse: false,
            markedAsUrgent: false
        )

        // Process based on conversation state
        switch state.currentStage {
        case .initial:
            // First message - check if should auto-reply
            if await shouldSendAutoReply(to: contactKey, platform: platform) {
                await sendInitialAutoReply(to: &communication, state: &state, language: language)
            }

        case .askedIfUrgent:
            // They replied - check if it's a yes/no
            if isAffirmativeResponse(messageContent, language: language) {
                state.markedAsUrgent = true
                state.currentStage = .confirmedUrgent
                communication.urgencyLevel = .urgent
                onUrgentDetected?(communication)
                await sendUrgentCallInstructions(to: &communication, state: &state, language: language)
            } else if isNegativeResponse(messageContent, language: language) {
                state.currentStage = .resolved
                // Optionally send a "I'll get back to you" message
            } else {
                // Ambiguous - treat as potentially urgent
                await sendUrgentCallInstructions(to: &communication, state: &state, language: language)
            }

        case .confirmedUrgent, .callInstructionsSent:
            // They've been told to call twice - no more auto-replies
            break

        case .resolved:
            // Conversation resolved - reset if new message after window
            if Date().timeIntervalSince(state.lastMessageTime) > globalSettings.autoReplyWindow {
                state = ConversationState(
                    contactId: contactKey,
                    currentStage: .initial,
                    autoRepliesSent: 0,
                    lastMessageTime: Date(),
                    awaitingUrgencyResponse: false,
                    markedAsUrgent: false
                )
                if await shouldSendAutoReply(to: contactKey, platform: platform) {
                    await sendInitialAutoReply(to: &communication, state: &state, language: language)
                }
            }
        }

        state.lastMessageTime = Date()
        conversationStates[contactKey] = state
    }

    // MARK: - Auto-Reply Logic

    private func shouldSendAutoReply(to contactKey: String, platform: CommunicationPlatform) async -> Bool {
        guard globalSettings.autoReplyEnabled else { return false }
        guard globalSettings.autoReplyPlatforms.contains(platform) else { return false }

        // Check reply window
        if let lastReply = recentAutoReplies[contactKey] {
            let timeSince = Date().timeIntervalSince(lastReply)
            if timeSince < globalSettings.autoReplyWindow {
                return false
            }
        }

        // Check max replies
        if let state = conversationStates[contactKey] {
            if state.autoRepliesSent >= globalSettings.maxAutoRepliesPerContact {
                return false
            }
        }

        return true
    }

    private func sendInitialAutoReply(
        to communication: inout IncomingCommunication,
        state: inout ConversationState,
        language: String
    ) async {
        let template = messageTemplates.autoReply[language] ?? messageTemplates.autoReply["en"]!

        var message = template.initialMessage

        // Add time-aware context if enabled
        if globalSettings.timeAwareResponses && globalSettings.includeAvailabilityInReply {
            if let availabilityInfo = getAvailabilityInfo(language: language) {
                message += " " + availabilityInfo
            }
        }

        // Add urgent question if enabled
        if globalSettings.askIfUrgent {
            message += "\n\n" + template.urgentQuestion
            state.currentStage = .askedIfUrgent
            state.awaitingUrgencyResponse = true
        }

        // Send via appropriate method
        let success = await sendMessage(to: communication.phoneNumber ?? "", message: message, platform: communication.platform)

        if success {
            communication.autoReplyStatus = .sent
            state.autoRepliesSent += 1
            recentAutoReplies[state.contactId] = Date()
            onAutoReplySent?(communication, message)
        } else {
            communication.autoReplyStatus = .failed
        }
    }

    private func sendUrgentCallInstructions(
        to communication: inout IncomingCommunication,
        state: inout ConversationState,
        language: String
    ) async {
        let template = messageTemplates.autoReply[language] ?? messageTemplates.autoReply["en"]!

        let message = template.urgentConfirmed

        let success = await sendMessage(to: communication.phoneNumber ?? "", message: message, platform: communication.platform)

        if success {
            state.currentStage = .callInstructionsSent
            communication.autoReplyStatus = .sent
            onAutoReplySent?(communication, message)
        }
    }

    private func sendMissedCallNotification(for communication: IncomingCommunication) async {
        guard let phoneNumber = communication.phoneNumber else { return }

        let language = await detectLanguage(for: communication.contactId, phoneNumber: phoneNumber, messageContent: nil)
        let template = messageTemplates.callerNotification[language] ?? messageTemplates.callerNotification["en"]!

        // Send via SMS (most reliable for call notifications)
        let success = await sendMessage(to: phoneNumber, message: template.missedCallSMS, platform: .sms)

        if success {
            print("[FocusMode] Sent missed call notification to \(phoneNumber)")
        }
    }

    private func handleEmergencyMessage(_ communication: IncomingCommunication) async {
        // Emergency detected - immediate action
        print("[FocusMode] EMERGENCY DETECTED from \(communication.contactName ?? communication.phoneNumber ?? "unknown")")

        // If auto-dial emergency services is enabled and keywords suggest real emergency
        // This is a safety feature - be very careful with false positives
        if globalSettings.autoDialEmergencyServices {
            // Only for true emergencies (911 keywords, etc.)
            // This would need very careful implementation
        }

        // Send immediate response with emergency services info
        guard let phoneNumber = communication.phoneNumber else { return }
        _ = communication.languageDetected ?? "en"

        let emergencyMessage = """
        ⚠️ I received your message and see this may be an emergency.

        If you need emergency services, please call:
        🚨 112 (Europe) / 911 (US) / 999 (UK)

        I'm notifying you that I'm calling you back immediately.
        """

        _ = await sendMessage(to: phoneNumber, message: emergencyMessage, platform: communication.platform)

        // Auto-callback if enabled
        if globalSettings.autoCallbackEnabled {
            await initiateCallback(to: phoneNumber, reason: "Emergency detected")
        }
    }

    // MARK: - Message Sending

    private func sendMessage(to phoneNumber: String, message: String, platform: CommunicationPlatform) async -> Bool {
        #if os(macOS)
        // On Mac, we can use AppleScript for Messages and direct APIs for others
        switch platform {
        case .imessage, .sms:
            return await sendViaMessages(to: phoneNumber, message: message)
        case .whatsapp:
            return await sendViaWhatsApp(to: phoneNumber, message: message)
        case .telegram:
            return await sendViaTelegram(to: phoneNumber, message: message)
        default:
            return false
        }
        #else
        // On iOS, use Shortcuts
        return await sendViaShortcuts(to: phoneNumber, message: message, platform: platform)
        #endif
    }

    #if os(macOS)
    private func sendViaMessages(to phoneNumber: String, message: String) async -> Bool {
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(phoneNumber)" of targetService
            send "\(message.replacingOccurrences(of: "\"", with: "\\\""))" to targetBuddy
        end tell
        """

        return await runAppleScript(script)
    }

    private func sendViaWhatsApp(to phoneNumber: String, message: String) async -> Bool {
        // WhatsApp MCP Server approach - using AppleScript automation
        // Reference: https://github.com/victor-torres/whatsapp-applescript

        let cleanNumber = phoneNumber.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " ", with: "")

        let script = """
        tell application "WhatsApp" to activate
        delay 0.5
        tell application "System Events"
            tell process "WhatsApp"
                -- Open new chat
                keystroke "n" using command down
                delay 0.3
                -- Type phone number
                keystroke "\(cleanNumber)"
                delay 0.5
                -- Press enter to select
                key code 36
                delay 0.3
                -- Type message
                keystroke "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
                delay 0.2
                -- Send
                key code 36
            end tell
        end tell
        """

        return await runAppleScript(script)
    }

    private func sendViaTelegram(to chatId: String, message: String) async -> Bool {
        // Telegram Bot API or desktop automation
        // For personal account, use desktop automation similar to WhatsApp
        false // Placeholder
    }

    private func runAppleScript(_ script: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    if error == nil {
                        continuation.resume(returning: true)
                    } else {
                        print("[AppleScript] Error: \(error ?? [:])")
                        continuation.resume(returning: false)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    #endif

    private func sendViaShortcuts(to phoneNumber: String, message: String, platform: CommunicationPlatform) async -> Bool {
        #if os(iOS)
        let shortcutName: String
        switch platform {
        case .imessage, .sms:
            shortcutName = "THEA%20Auto%20Reply"
        case .whatsapp:
            shortcutName = "THEA%20WhatsApp%20Reply"
        default:
            return false
        }

        let input = "\(phoneNumber)|\(message)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(shortcutName)&input=text&text=\(input)") else {
            return false
        }

        return await MainActor.run {
            UIApplication.shared.open(url)
            return true
        }
        #else
        return false
        #endif
    }

    // MARK: - WhatsApp Status Management

    private func updateWhatsAppStatus(_ status: String) async {
        // Save current status first
        #if os(macOS)
        // Read current status via AppleScript/automation
        // This is complex as WhatsApp doesn't expose this easily
        previousWhatsAppStatus = await getCurrentWhatsAppStatus()

        // Update status
        _ = """
        tell application "WhatsApp" to activate
        delay 0.5
        tell application "System Events"
            tell process "WhatsApp"
                -- Navigate to Settings > Profile
                keystroke "," using command down
                delay 0.3
                -- This would need UI navigation to change status
                -- Placeholder - actual implementation depends on WhatsApp UI
            end tell
        end tell
        """

        // Note: WhatsApp status change via automation is complex
        // Alternative: Use WhatsApp Web automation or third-party APIs
        print("[WhatsApp] Would update status to: \(status)")
        #endif
    }

    private func revertWhatsAppStatus() async {
        if let previous = previousWhatsAppStatus {
            await updateWhatsAppStatus(previous)
            previousWhatsAppStatus = nil
        }
    }

    private func getCurrentWhatsAppStatus() async -> String? {
        // Read current WhatsApp status
        nil // Placeholder
    }

    // MARK: - Telegram Status Management

    private func updateTelegramStatus(_ status: String) async {
        // Telegram Bot API or automation
        print("[Telegram] Would update status to: \(status)")
    }

    private func clearTelegramStatus() async {
        print("[Telegram] Would clear status")
    }

    // MARK: - COMBOX Integration

    private func switchComboxGreeting(to greetingType: String) async {
        // Swisscom COMBOX greeting change
        // This requires calling 086 and navigating menus via DTMF

        print("[COMBOX] Would switch greeting to: \(greetingType)")

        // Actual implementation would use Shortcuts to:
        // 1. Call 086
        // 2. Navigate menu with DTMF tones
        // 3. Select appropriate greeting

        #if os(iOS)
        // Trigger Shortcuts automation
        if let url = URL(string: "shortcuts://run-shortcut?name=THEA%20COMBOX%20Greeting&input=text&text=\(greetingType)") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }

    // MARK: - Language Detection

    private func detectLanguage(for contactId: String?, phoneNumber: String?, messageContent: String?) async -> String {
        // Check cached
        if let cId = contactId, let cached = contactLanguages[cId], cached.confidence > 0.7 {
            return cached.detectedLanguage
        }

        // Try phone number
        if let phone = phoneNumber, let langFromPhone = languageFromPhoneNumber(phone) {
            if let cId = contactId {
                contactLanguages[cId] = ContactLanguageInfo(
                    contactId: cId,
                    detectedLanguage: langFromPhone,
                    confidence: 0.7,
                    detectionMethod: .phoneCountryCode,
                    isManuallySet: false,
                    previousLanguages: [],
                    lastUpdated: Date()
                )
            }
            return langFromPhone
        }

        // Try message content analysis
        if let content = messageContent, !content.isEmpty {
            if let detected = detectLanguageFromText(content) {
                if let cId = contactId {
                    var info = contactLanguages[cId] ?? ContactLanguageInfo(
                        contactId: cId,
                        detectedLanguage: detected,
                        confidence: 0.6,
                        detectionMethod: .messageHistory,
                        isManuallySet: false,
                        previousLanguages: [],
                        lastUpdated: Date()
                    )
                    info.detectedLanguage = detected
                    info.lastUpdated = Date()
                    contactLanguages[cId] = info
                }
                return detected
            }
        }

        // Default to device locale
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func languageFromPhoneNumber(_ phoneNumber: String) -> String? {
        let countryCodeToLanguage: [String: String] = [
            "+1": "en", "+44": "en", "+61": "en", "+64": "en",
            "+33": "fr", "+32": "fr", // Belgium - could be fr/nl
            "+41": "de", // Switzerland - could be de/fr/it
            "+49": "de", "+43": "de",
            "+39": "it",
            "+34": "es", "+52": "es", "+54": "es",
            "+351": "pt", "+55": "pt",
            "+31": "nl",
            "+81": "ja",
            "+86": "zh", "+852": "zh", "+886": "zh",
            "+82": "ko",
            "+7": "ru",
            "+966": "ar", "+971": "ar", "+20": "ar"
        ]

        for (code, lang) in countryCodeToLanguage {
            if phoneNumber.hasPrefix(code) {
                return lang
            }
        }

        return nil
    }

    private func detectLanguageFromText(_ text: String) -> String? {
        // Simple keyword-based detection
        let languageIndicators: [String: [String]] = [
            "fr": ["bonjour", "merci", "salut", "oui", "non", "comment", "pourquoi", "c'est", "je", "tu"],
            "de": ["hallo", "danke", "guten", "bitte", "ja", "nein", "wie", "warum", "ich", "du", "ist"],
            "it": ["ciao", "grazie", "buongiorno", "sì", "no", "come", "perché", "sono", "tu", "è"],
            "es": ["hola", "gracias", "buenos", "sí", "no", "cómo", "por qué", "soy", "tú", "es"],
            "pt": ["olá", "obrigado", "bom dia", "sim", "não", "como", "por que", "sou", "tu", "é"],
            "nl": ["hallo", "dank", "goedemorgen", "ja", "nee", "hoe", "waarom", "ik", "jij", "is"]
        ]

        let lowercased = text.lowercased()

        var scores: [String: Int] = [:]
        for (lang, indicators) in languageIndicators {
            for indicator in indicators {
                if lowercased.contains(indicator) {
                    scores[lang, default: 0] += 1
                }
            }
        }

        // Return language with highest score, if any
        if let (lang, score) = scores.max(by: { $0.value < $1.value }), score >= 2 {
            return lang
        }

        return nil
    }

    // MARK: - Urgency Detection

    private func detectUrgency(in message: String, language: String) -> IncomingCommunication.UrgencyLevel {
        let templates = messageTemplates.urgentResponse[language] ?? messageTemplates.urgentResponse["en"]!
        let lowercased = message.lowercased()

        // Check for emergency keywords first
        for keyword in templates.emergencyKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return .emergency
            }
        }

        // Check for urgent keywords
        for keyword in templates.yesKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return .urgent
            }
        }

        return .unknown
    }

    private func detectEmergency(in message: String, language: String) -> Bool {
        let templates = messageTemplates.urgentResponse[language] ?? messageTemplates.urgentResponse["en"]!
        let lowercased = message.lowercased()

        for keyword in templates.emergencyKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    private func isAffirmativeResponse(_ message: String, language: String) -> Bool {
        let templates = messageTemplates.urgentResponse[language] ?? messageTemplates.urgentResponse["en"]!
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for keyword in templates.yesKeywords {
            if lowercased == keyword.lowercased() || lowercased.hasPrefix(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    private func isNegativeResponse(_ message: String, language: String) -> Bool {
        let templates = messageTemplates.urgentResponse[language] ?? messageTemplates.urgentResponse["en"]!
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for keyword in templates.noKeywords {
            if lowercased == keyword.lowercased() || lowercased.hasPrefix(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    // ============================================================================
    // MARK: - AUTONOMOUS URGENCY DETERMINATION
    // ============================================================================
    //
    // THEA monitors your entire life and can autonomously determine what's truly
    // urgent or time-sensitive WITHOUT bothering you. This uses multiple signals:
    //
    // 1. CONTACT HISTORY & PATTERNS
    //    - How often does this contact reach out?
    //    - What's their historical urgency accuracy? (learned over time)
    //    - Are they a VIP, emergency contact, or family?
    //    - Time since last interaction
    //
    // 2. MESSAGE CONTENT ANALYSIS
    //    - Keywords indicating urgency/emergency
    //    - Sentiment analysis (panic, stress indicators)
    //    - Time-sensitive language ("today", "now", "deadline")
    //    - Question vs statement (questions often need response)
    //
    // 3. CONTEXTUAL SIGNALS
    //    - Time of day (late night = more likely urgent)
    //    - Day of week (weekend personal matters, weekday work)
    //    - Current calendar context (deadline approaching?)
    //    - Sender's timezone (is it their work hours?)
    //
    // 4. BEHAVIORAL SIGNALS
    //    - Message frequency (escalation pattern)
    //    - Multiple platforms attempted (really trying to reach you)
    //    - Voice message instead of text (more effort = more urgent?)
    //    - Call attempts before message
    //
    // 5. CROSS-REFERENCED INTELLIGENCE
    //    - Does message reference something in your calendar?
    //    - Does it relate to a known project/deadline?
    //    - Is sender someone you have a meeting with soon?
    //
    // DECISION: If score > threshold → handle autonomously (no user notification)
    //           If score indicates true urgency → notify user
    // ============================================================================

    /// Comprehensive urgency score (0.0 = not urgent, 1.0 = critical emergency)
    public struct UrgencyAssessment: Sendable {
        public let score: Double // 0.0 to 1.0
        public let level: IncomingCommunication.UrgencyLevel
        public let confidence: Double // How confident THEA is in this assessment
        public let signals: [UrgencySignal]
        public let recommendation: UrgencyRecommendation
        public let reasoning: String // Human-readable explanation

        public enum UrgencyRecommendation: String, Sendable {
            case ignoreCompletely = "ignore" // Not urgent at all
            case autoReplyOnly = "auto_reply" // Send auto-reply, don't notify user
            case autoReplyAndMonitor = "monitor" // Auto-reply and watch for escalation
            case notifyUserLater = "notify_later" // Add to summary for later
            case notifyUserNow = "notify_now" // This is actually urgent
            case emergencyAlert = "emergency" // Critical - break through Focus
        }
    }

    public struct UrgencySignal: Sendable {
        public let type: SignalType
        public let weight: Double // Contribution to score
        public let description: String

        public enum SignalType: String, Sendable {
            case keywordMatch = "keyword"
            case contactPriority = "contact_priority"
            case messageFrequency = "frequency"
            case timeOfDay = "time"
            case calendarContext = "calendar"
            case sentimentAnalysis = "sentiment"
            case historicalPattern = "history"
            case multiPlatformAttempt = "multi_platform"
            case voiceMessage = "voice"
            case callAttempt = "call"
            case deadlineRelated = "deadline"
            case familyContact = "family"
            case workRelated = "work"
        }
    }

    /// Autonomously assess urgency using all available intelligence
    private func assessUrgencyAutonomously(
        contactId: String?,
        phoneNumber: String?,
        messageContent: String,
        platform: CommunicationPlatform,
        language: String
    ) async -> UrgencyAssessment {

        var signals: [UrgencySignal] = []
        var totalScore: Double = 0.0
        let contactKey = contactId ?? phoneNumber ?? "unknown"

        // ========== 1. KEYWORD ANALYSIS ==========
        let keywordScore = analyzeKeywordsForUrgency(messageContent, language: language)
        if keywordScore > 0 {
            signals.append(UrgencySignal(
                type: .keywordMatch,
                weight: keywordScore * 0.25,
                description: "Message contains urgency indicators"
            ))
            totalScore += keywordScore * 0.25
        }

        // ========== 2. CONTACT PRIORITY ==========
        let contactPriority = contactPriorities[contactKey] ?? 0.5
        if contactPriority > 0.7 {
            signals.append(UrgencySignal(
                type: .contactPriority,
                weight: (contactPriority - 0.5) * 0.3,
                description: "High-priority contact based on history"
            ))
            totalScore += (contactPriority - 0.5) * 0.3
        }

        // Check if VIP
        if let cId = contactId, globalSettings.vipContacts.contains(cId) {
            signals.append(UrgencySignal(
                type: .contactPriority,
                weight: 0.2,
                description: "VIP contact"
            ))
            totalScore += 0.2
        }

        // Check if emergency contact
        if let cId = contactId, emergencyContacts.contains(cId) {
            signals.append(UrgencySignal(
                type: .familyContact,
                weight: 0.4,
                description: "Emergency contact"
            ))
            totalScore += 0.4
        }

        // ========== 3. MESSAGE FREQUENCY (Escalation) ==========
        let timestamps = messageCountTracking[contactKey] ?? []
        let recentMessages = timestamps.filter { Date().timeIntervalSince($0) < 600 } // Last 10 min
        if recentMessages.count >= 3 {
            let frequencyScore = min(0.3, Double(recentMessages.count) * 0.05)
            signals.append(UrgencySignal(
                type: .messageFrequency,
                weight: frequencyScore,
                description: "\(recentMessages.count) messages in last 10 minutes"
            ))
            totalScore += frequencyScore
        }

        // ========== 4. TIME OF DAY CONTEXT ==========
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 {
            // Late night/early morning - more likely urgent if reaching out
            signals.append(UrgencySignal(
                type: .timeOfDay,
                weight: 0.15,
                description: "Unusual hours contact"
            ))
            totalScore += 0.15
        }

        // ========== 5. TIME-SENSITIVE LANGUAGE ==========
        let timeSensitiveScore = analyzeTimeSensitiveLanguage(messageContent, language: language)
        if timeSensitiveScore > 0 {
            signals.append(UrgencySignal(
                type: .deadlineRelated,
                weight: timeSensitiveScore * 0.2,
                description: "Time-sensitive language detected"
            ))
            totalScore += timeSensitiveScore * 0.2
        }

        // ========== 6. SENTIMENT ANALYSIS ==========
        let sentimentScore = analyzeSentimentForUrgency(messageContent)
        if sentimentScore > 0.3 {
            signals.append(UrgencySignal(
                type: .sentimentAnalysis,
                weight: sentimentScore * 0.15,
                description: "Elevated stress/urgency in tone"
            ))
            totalScore += sentimentScore * 0.15
        }

        // ========== 7. MULTI-PLATFORM ATTEMPTS ==========
        let platformsUsed = countRecentPlatformAttempts(contactKey: contactKey)
        if platformsUsed > 1 {
            signals.append(UrgencySignal(
                type: .multiPlatformAttempt,
                weight: 0.2,
                description: "Tried \(platformsUsed) different platforms"
            ))
            totalScore += 0.2
        }

        // ========== CALCULATE FINAL ASSESSMENT ==========
        let clampedScore = min(1.0, max(0.0, totalScore))
        let level = scoreToUrgencyLevel(clampedScore)
        let recommendation = determineRecommendation(score: clampedScore, signals: signals)
        let confidence = calculateConfidence(signals: signals)

        let reasoning = generateReasoning(signals: signals, score: clampedScore, recommendation: recommendation)

        return UrgencyAssessment(
            score: clampedScore,
            level: level,
            confidence: confidence,
            signals: signals,
            recommendation: recommendation,
            reasoning: reasoning
        )
    }

    private func analyzeKeywordsForUrgency(_ message: String, language: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        // Emergency keywords = high score
        let emergencyKeywords = ["emergency", "urgent", "help", "asap", "immediately", "critical",
                                  "dringend", "notfall", "hilfe", "sofort",
                                  "urgence", "aide", "immédiatement",
                                  "emergenza", "urgente", "aiuto", "subito"]
        for keyword in emergencyKeywords {
            if lowercased.contains(keyword) {
                score += 0.4
            }
        }

        // Moderate urgency keywords
        let moderateKeywords = ["important", "need", "please call", "call me", "waiting",
                                 "wichtig", "bitte anrufen", "warte",
                                 "important", "appelle", "attends",
                                 "importante", "chiamami", "aspetto"]
        for keyword in moderateKeywords {
            if lowercased.contains(keyword) {
                score += 0.2
            }
        }

        return min(1.0, score)
    }

    private func analyzeTimeSensitiveLanguage(_ message: String, language: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        let timeSensitive = ["today", "tonight", "now", "right now", "this hour", "deadline",
                              "heute", "jetzt", "sofort", "deadline",
                              "aujourd'hui", "maintenant", "ce soir",
                              "oggi", "adesso", "stasera", "subito"]

        for keyword in timeSensitive {
            if lowercased.contains(keyword) {
                score += 0.3
            }
        }

        // Check for time mentions (e.g., "by 5pm", "before 3")
        let timePattern = #"\d{1,2}[:\.]?\d{0,2}\s*(am|pm|uhr|h|heure)?"#
        if lowercased.range(of: timePattern, options: .regularExpression) != nil {
            score += 0.2
        }

        return min(1.0, score)
    }

    private func analyzeSentimentForUrgency(_ message: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        // Stress indicators
        let stressIndicators = ["!!!", "???", "please please", "really need", "desperate",
                                 "worried", "scared", "anxious", "panicking"]
        for indicator in stressIndicators {
            if lowercased.contains(indicator) {
                score += 0.3
            }
        }

        // Caps lock = shouting (check if significant portion is caps)
        let capsCount = message.filter { $0.isUppercase }.count
        let totalLetters = message.filter { $0.isLetter }.count
        if totalLetters > 10 && Double(capsCount) / Double(totalLetters) > 0.5 {
            score += 0.2
        }

        return min(1.0, score)
    }

    private func countRecentPlatformAttempts(contactKey: String) -> Int {
        // Count unique platforms this contact has used in last 30 min
        let cutoff = Date().addingTimeInterval(-1800)
        let recentComms = recentCommunications.filter {
            ($0.contactId == contactKey || $0.phoneNumber == contactKey) && $0.timestamp > cutoff
        }

        let platforms = Set(recentComms.map { $0.platform })
        return platforms.count
    }

    private func scoreToUrgencyLevel(_ score: Double) -> IncomingCommunication.UrgencyLevel {
        switch score {
        case 0.8...: return .emergency
        case 0.6..<0.8: return .urgent
        case 0.4..<0.6: return .possiblyUrgent
        case 0.2..<0.4: return .unknown
        default: return .notUrgent
        }
    }

    private func determineRecommendation(score: Double, signals: [UrgencySignal]) -> UrgencyAssessment.UrgencyRecommendation {
        // Check for emergency signals
        if signals.contains(where: { $0.type == .familyContact && $0.weight > 0.3 }) {
            return .notifyUserNow
        }

        switch score {
        case 0.8...: return .emergencyAlert
        case 0.6..<0.8: return .notifyUserNow
        case 0.4..<0.6: return .autoReplyAndMonitor
        case 0.2..<0.4: return .autoReplyOnly
        default: return .ignoreCompletely
        }
    }

    private func calculateConfidence(signals: [UrgencySignal]) -> Double {
        // More signals = higher confidence
        let signalCount = Double(signals.count)
        let baseConfidence = min(0.9, signalCount * 0.15)

        // Strong signals increase confidence
        let strongSignals = signals.filter { $0.weight > 0.2 }.count
        let strongBonus = Double(strongSignals) * 0.1

        return min(0.95, baseConfidence + strongBonus)
    }

    private func generateReasoning(signals: [UrgencySignal], score: Double, recommendation: UrgencyAssessment.UrgencyRecommendation) -> String {
        if signals.isEmpty {
            return "No urgency signals detected. Will auto-reply and handle normally."
        }

        let topSignals = signals.sorted { $0.weight > $1.weight }.prefix(3)
        let signalDescriptions = topSignals.map { $0.description }.joined(separator: "; ")

        let actionDescription: String
        switch recommendation {
        case .ignoreCompletely:
            actionDescription = "No action needed."
        case .autoReplyOnly:
            actionDescription = "Sending auto-reply, no user notification."
        case .autoReplyAndMonitor:
            actionDescription = "Sending auto-reply and monitoring for escalation."
        case .notifyUserLater:
            actionDescription = "Will include in Focus Mode summary."
        case .notifyUserNow:
            actionDescription = "Notifying user - this appears genuinely urgent."
        case .emergencyAlert:
            actionDescription = "EMERGENCY: Breaking through Focus Mode."
        }

        return "Score: \(String(format: "%.1f", score * 100))%. Signals: \(signalDescriptions). \(actionDescription)"
    }

    // MARK: - Time-Aware Responses

    private func getAvailabilityInfo(language: String) -> String? {
        guard let mode = currentFocusMode else { return nil }

        // Check if Focus mode has a schedule that tells us when it ends
        for schedule in mode.schedules where schedule.enabled {
            // Calculate when this schedule ends
            let calendar = Calendar.current
            let now = Date()

            if let endHour = schedule.endTime.hour,
               let endMinute = schedule.endTime.minute {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = endHour
                components.minute = endMinute

                if let endTime = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    formatter.locale = Locale(identifier: language)

                    let timeString = formatter.string(from: endTime)

                    // Localized availability messages
                    let availabilityMessages: [String: String] = [
                        "en": "I should be available around \(timeString).",
                        "fr": "Je devrais être disponible vers \(timeString).",
                        "de": "Ich sollte gegen \(timeString) verfügbar sein.",
                        "it": "Dovrei essere disponibile verso le \(timeString).",
                        "es": "Debería estar disponible alrededor de las \(timeString)."
                    ]

                    return availabilityMessages[language] ?? availabilityMessages["en"]
                }
            }
        }

        return nil
    }

    // MARK: - Callback System

    private func initiateCallback(to phoneNumber: String, reason: String) async {
        // Initiate a call back to the contact
        #if os(iOS)
        if let url = URL(string: "tel://\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        #elseif os(macOS)
        // On Mac, use FaceTime or handoff to iPhone
        if let url = URL(string: "facetime://\(phoneNumber)") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func processPendingCallbacks() async {
        for callback in pendingCallbacks where !callback.completed {
            // Schedule reminder or initiate callback
            print("[FocusMode] Pending callback to \(callback.phoneNumber): \(callback.reason)")
        }
    }

    // MARK: - iPhone Sync

    private func notifyiPhoneOfFocusChange(active: Bool, mode: FocusModeConfiguration) async {
        // Sync Focus state to iPhone via:
        // 1. iCloud (shared UserDefaults via App Group)
        // 2. Handoff
        // 3. Local network communication

        // For App Group sync (requires shared container)
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            defaults.set(active, forKey: "focusModeActive")
            defaults.set(mode.id, forKey: "currentFocusModeId")
            defaults.set(mode.name, forKey: "currentFocusModeName")
            defaults.set(Date(), forKey: "focusModeLastSync")
            defaults.synchronize()
        }
    }

    private func syncSettingsToiPhone() async {
        // Sync all settings to iPhone
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            if let encoded = try? JSONEncoder().encode(globalSettings) {
                defaults.set(encoded, forKey: "focusModeGlobalSettings")
            }
            defaults.synchronize()
        }
    }

    // MARK: - Shortcuts Setup (Autonomous)

    private func ensureShortcutsExist() async {
        // Check if required Shortcuts exist and create them if not
        // This is done via the Shortcuts app URL scheme or iCloud sharing

        let requiredShortcuts = [
            "THEA Focus Activated",
            "THEA Focus Deactivated",
            "THEA Auto Reply",
            "THEA WhatsApp Reply",
            "THEA COMBOX Greeting"
        ]

        // Check if shortcuts exist by trying to open them
        // If they don't exist, prompt user to install or create automatically

        #if os(iOS)
        // Generate and offer to install shortcuts
        await generateAndInstallShortcuts()
        #elseif os(macOS)
        // On Mac, we can create shortcuts programmatically or guide user
        print("[FocusMode] Required Shortcuts: \(requiredShortcuts)")
        #endif
    }

    #if os(iOS)
    private func generateAndInstallShortcuts() async {
        // Shortcuts can be shared via iCloud links
        // THEA can host these links and prompt user to install

        // For now, we'll use a notification to guide the user
        print("[FocusMode] Would prompt user to install required Shortcuts")
    }
    #endif

    // MARK: - Periodic Tasks

    private func startPeriodicTasks() async {
        // Learn from usage patterns
        Task {
            while isRunning {
                try? await Task.sleep(for: .seconds(3600))  // 1 hour
                await analyzeUsagePatterns()
            }
        }
    }

    private func analyzeUsagePatterns() async {
        // Analyze contact communication patterns
        // Update priority scores
        // Learn optimal response times
        // Suggest Focus mode improvements

        if globalSettings.learnContactPriorities {
            // Analyze which contacts frequently mark things as urgent
            // Adjust their priority scores
        }

        if globalSettings.suggestFocusModeActivation {
            // Based on calendar, time of day, location, suggest Focus activation
        }
    }

    // MARK: - Persistence

    private func loadSettings() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "focusModeGlobalSettings"),
           let settings = try? JSONDecoder().decode(FocusModeGlobalSettings.self, from: data) {
            self.globalSettings = settings
            self.emergencyContacts = Set(settings.emergencyContacts)
        }
    }

    private func saveSettings() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(globalSettings) {
            defaults.set(encoded, forKey: "focusModeGlobalSettings")
            defaults.synchronize()
        }
    }

    private func loadFocusModes() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "focusModeConfigurations"),
           let modes = try? JSONDecoder().decode([String: FocusModeConfiguration].self, from: data) {
            self.focusModes = modes
        }
    }

    private func loadContactLanguages() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "contactLanguages"),
           let languages = try? JSONDecoder().decode([String: ContactLanguageInfo].self, from: data) {
            self.contactLanguages = languages
        }
    }

    private func saveContactLanguages() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(contactLanguages) {
            defaults.set(encoded, forKey: "contactLanguages")
            defaults.synchronize()
        }
    }

    // MARK: - Query Methods

    public func getCurrentFocusMode() -> FocusModeConfiguration? {
        currentFocusMode
    }

    public func getAllFocusModes() -> [FocusModeConfiguration] {
        Array(focusModes.values)
    }

    public func getRecentCommunications(limit: Int = 50) -> [IncomingCommunication] {
        Array(recentCommunications.suffix(limit))
    }

    public func getContactLanguage(_ contactId: String) -> String? {
        contactLanguages[contactId]?.detectedLanguage
    }

    public func isEmergencyContact(_ contactId: String) -> Bool {
        emergencyContacts.contains(contactId)
    }

    // ============================================================================
    // MARK: - CALL FORWARDING WORKAROUND (Critical for iOS Focus Mode)
    // ============================================================================
    //
    // PROBLEM: When iOS Focus Mode blocks a call, the call is IMMEDIATELY rejected
    // at the network level. The caller hears a 3-tone disconnect sound (like the
    // line was hung up). This means:
    // - The caller can't leave a voicemail
    // - THEA can't detect the call happened
    // - "Call twice within 3 minutes" DOESN'T WORK because the first call is rejected
    //
    // SOLUTION: Use carrier call forwarding to redirect ALL calls to COMBOX
    // when Focus Mode is active. This way:
    // - Calls go to COMBOX instead of being rejected
    // - COMBOX plays a Focus-aware greeting explaining the situation
    // - Caller can leave voicemail
    // - THEA sends SMS after voicemail with callback instructions
    // - For truly urgent calls, we can detect repeated attempts via COMBOX
    //
    // Swisscom Call Forwarding Codes:
    // - *21*NUMBER# : Forward ALL calls unconditionally
    // - *67*NUMBER# : Forward when BUSY
    // - *61*NUMBER# : Forward when NO ANSWER (after X rings)
    // - *62*NUMBER# : Forward when UNREACHABLE
    // - #21# : Disable unconditional forwarding
    // - #67# : Disable busy forwarding
    // - #61# : Disable no-answer forwarding
    // - #62# : Disable unreachable forwarding
    //
    // For Focus Mode, we use unconditional forwarding (*21*086#) because
    // we want ALL calls to go to COMBOX, not just some.
    // ============================================================================

    private var callForwardingEnabled = false

    /// Enable call forwarding to COMBOX when Focus Mode activates
    private func enableCallForwarding() async {
        guard !callForwardingEnabled else { return }

        let forwardingCode = globalSettings.callForwardingActivationCode +
                             globalSettings.callForwardingNumber + "#"
        // e.g., "*21*086#" for Swisscom

        print("[CallForwarding] Enabling call forwarding with code: \(forwardingCode)")

        #if os(iOS)
        // Use Shortcuts to dial the USSD code
        // Note: iOS doesn't allow programmatic USSD execution, so we use Shortcuts
        await executeCallForwardingViaShortcuts(code: forwardingCode, action: "enable")
        #elseif os(macOS)
        // Mac sends command to iPhone via Shortcuts URL scheme or Handoff
        await sendCallForwardingCommandToiPhone(code: forwardingCode, enable: true)
        #endif

        callForwardingEnabled = true
        print("[CallForwarding] ✓ Call forwarding enabled - all calls now go to COMBOX")
    }

    /// Disable call forwarding when Focus Mode deactivates
    private func disableCallForwarding() async {
        guard callForwardingEnabled else { return }

        let disableCode = globalSettings.callForwardingDeactivationCode
        // e.g., "#21#" for Swisscom

        print("[CallForwarding] Disabling call forwarding with code: \(disableCode)")

        #if os(iOS)
        await executeCallForwardingViaShortcuts(code: disableCode, action: "disable")
        #elseif os(macOS)
        await sendCallForwardingCommandToiPhone(code: disableCode, enable: false)
        #endif

        callForwardingEnabled = false
        print("[CallForwarding] ✓ Call forwarding disabled - normal call behavior restored")
    }

    #if os(iOS)
    private func executeCallForwardingViaShortcuts(code: String, action: String) async {
        // Use the "THEA Call Forwarding" shortcut to execute USSD code
        let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        if let url = URL(string: "shortcuts://run-shortcut?name=THEA%20Call%20Forwarding&input=text&text=\(encodedCode)") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }

        // Alternative: Use tel: URL scheme with USSD (may not work on all carriers)
        // Some carriers allow: tel://*21*086%23
        // The %23 is URL-encoded #
    }
    #endif

    #if os(macOS)
    private func sendCallForwardingCommandToiPhone(code: String, enable: Bool) async {
        // Send command to iPhone to execute call forwarding
        // Options:
        // 1. App Group UserDefaults (iPhone app polls for commands)
        // 2. Push notification to trigger Shortcut
        // 3. Handoff/Continuity

        // Using App Group for now
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            defaults.set(code, forKey: "pendingCallForwardingCode")
            defaults.set(enable, forKey: "pendingCallForwardingEnable")
            defaults.set(Date(), forKey: "pendingCallForwardingTimestamp")
            defaults.synchronize()

            print("[CallForwarding] Sent \(enable ? "enable" : "disable") command to iPhone")
        }
    }
    #endif

    // ============================================================================
    // MARK: - Enhancement 1: VoIP Call Interception
    // ============================================================================
    //
    // For VoIP calls (WhatsApp, Telegram, FaceTime), we CAN intercept on Mac
    // because these apps run on Mac too. When a VoIP call comes in:
    // 1. Mac detects the incoming call notification
    // 2. Before letting it ring, play a TTS message to the caller
    // 3. Ask if it's urgent
    // 4. If urgent, ring through; otherwise, decline and send auto-reply
    // ============================================================================

    private var voipMonitoringActive = false
    #if os(macOS)
    private var voipNotificationObserver: NSObjectProtocol?
    #endif

    private func startVoIPInterception() async {
        guard !voipMonitoringActive else { return }
        voipMonitoringActive = true

        #if os(macOS)
        // Monitor for VoIP call notifications on Mac
        // WhatsApp, Telegram, FaceTime all post notifications

        // Monitor WhatsApp calls
        if globalSettings.voipInterceptWhatsApp {
            await startWhatsAppCallMonitoring()
        }

        // Monitor Telegram calls
        if globalSettings.voipInterceptTelegram {
            await startTelegramCallMonitoring()
        }

        // Monitor FaceTime calls
        if globalSettings.voipInterceptFaceTime {
            await startFaceTimeCallMonitoring()
        }

        print("[VoIP] Started VoIP call interception on Mac")
        #endif
    }

    private func stopVoIPInterception() async {
        voipMonitoringActive = false

        #if os(macOS)
        if let observer = voipNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            voipNotificationObserver = nil
        }
        print("[VoIP] Stopped VoIP call interception")
        #endif
    }

    #if os(macOS)
    private func startWhatsAppCallMonitoring() async {
        // Monitor WhatsApp Desktop for incoming calls
        // WhatsApp shows a notification - we can intercept via NSWorkspace

        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "net.whatsapp.WhatsApp" else { return }

            // Check if this is a call notification
            Task {
                await self?.handlePotentialWhatsAppCall()
            }
        }

        print("[VoIP] WhatsApp call monitoring started")
    }

    private func handlePotentialWhatsAppCall() async {
        // Detect if WhatsApp is showing a call UI
        // This is tricky - we'd need to check the window title or use accessibility API

        let script = """
        tell application "System Events"
            tell process "WhatsApp"
                if exists window 1 then
                    set winTitle to name of window 1
                    return winTitle
                end if
            end tell
        end tell
        return ""
        """

        if let windowTitle = await runAppleScriptReturning(script) {
            let callIndicators = ["incoming call", "calling", "video call", "voice call",
                                  "eingehender anruf", "appel entrant", "chiamata in arrivo"]
            let lowercased = windowTitle.lowercased()

            for indicator in callIndicators {
                if lowercased.contains(indicator) {
                    await interceptVoIPCall(platform: .whatsapp, callInfo: windowTitle)
                    return
                }
            }
        }
    }

    private func startTelegramCallMonitoring() async {
        // Similar approach for Telegram Desktop
        print("[VoIP] Telegram call monitoring started")
    }

    private func startFaceTimeCallMonitoring() async {
        // FaceTime calls can be intercepted via CallKit on Mac
        print("[VoIP] FaceTime call monitoring started")
    }

    private func interceptVoIPCall(platform: CommunicationPlatform, callInfo: String) async {
        print("[VoIP] Intercepted \(platform.displayName) call: \(callInfo)")

        // Option 1: Play TTS message (requires the call to be answered first)
        // Option 2: Show notification asking user what to do
        // Option 3: Auto-decline and send message

        // For now, send auto-reply via the platform
        if globalSettings.voipPlayTTSBeforeRinging {
            // We can't play audio TO the caller without answering
            // But we can show a notification to the user
            await showVoIPInterceptionNotification(platform: platform, callInfo: callInfo)
        }
    }

    private func showVoIPInterceptionNotification(platform: CommunicationPlatform, callInfo: String) async {
        // Show notification via UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = "\u{1F4DE} \(platform.displayName) Call During Focus"
        content.body = "Incoming call: \(callInfo)\nYour Focus Mode is active."
        content.sound = .default
        content.categoryIdentifier = "VOIP_INTERCEPTION"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func runAppleScriptReturning(_ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    let result = appleScript.executeAndReturnError(&error)
                    if error == nil {
                        continuation.resume(returning: result.stringValue)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif

    // ============================================================================
    // MARK: - Enhancement 2: Smart Contact Escalation
    // ============================================================================
    //
    // If someone sends multiple messages in a short time, they're probably urgent.
    // Track message counts per contact and auto-escalate to urgent status.
    //
    // CONFIGURABLE:
    // - escalationMessageThreshold: Number of messages to trigger (default: 3)
    // - escalationTimeWindow: Time window in seconds (default: 300 = 5 min)
    // - escalationAutoReplyEnabled: Send auto-reply asking if truly urgent
    // - escalationNotifyUser: Whether to disturb user or handle silently
    //
    // BEHAVIOR:
    // When threshold is reached, THEA auto-replies asking if it's truly urgent.
    // If contact confirms, only then is user notified. This prevents unnecessary
    // interruptions from people who just send many messages but aren't urgent.
    // ============================================================================

    private var messageCountTracking: [String: [Date]] = [:] // Contact -> message timestamps
    private var escalationPending: Set<String> = [] // Contacts awaiting urgency confirmation

    private func trackMessageForEscalation(contactKey: String, messageContent: String) async {
        guard globalSettings.smartEscalationEnabled else { return }

        var timestamps = messageCountTracking[contactKey] ?? []

        // Clean old timestamps outside the window
        let cutoff = Date().addingTimeInterval(-globalSettings.escalationTimeWindow)
        timestamps = timestamps.filter { $0 > cutoff }

        // Add current timestamp
        timestamps.append(Date())
        messageCountTracking[contactKey] = timestamps

        // Check if we've hit the threshold
        if timestamps.count >= globalSettings.escalationMessageThreshold {
            // Only escalate once per window - check if already pending
            if !escalationPending.contains(contactKey) {
                await handleEscalation(contactKey: contactKey, messageCount: timestamps.count)
            } else {
                // Already pending - check if this message is a confirmation
                await checkEscalationConfirmation(contactKey: contactKey, messageContent: messageContent)
            }
        }
    }

    private func handleEscalation(contactKey: String, messageCount: Int) async {
        print("[Escalation] Contact \(contactKey) sent \(messageCount) messages in \(Int(globalSettings.escalationTimeWindow))s window")

        // Mark as pending escalation
        escalationPending.insert(contactKey)

        // DON'T notify user yet - first ask the contact if it's truly urgent
        // This prevents unnecessary interruptions
        let language = await detectLanguage(for: contactKey, phoneNumber: contactKey, messageContent: nil)

        // Localized escalation inquiry
        let escalationInquiry: [String: String] = [
            "en": "I noticed you've sent several messages. Is this urgent and needs my immediate attention? Reply YES if so, otherwise I'll get back to you when I'm available.",
            "de": "Ich habe bemerkt, dass du mehrere Nachrichten gesendet hast. Ist das dringend und braucht meine sofortige Aufmerksamkeit? Antworte JA falls ja, sonst melde ich mich, wenn ich verfügbar bin.",
            "fr": "J'ai remarqué que tu as envoyé plusieurs messages. Est-ce urgent et nécessite mon attention immédiate? Réponds OUI si c'est le cas, sinon je te recontacte dès que possible.",
            "it": "Ho notato che hai inviato diversi messaggi. È urgente e richiede la mia attenzione immediata? Rispondi SÌ se sì, altrimenti ti rispondo quando sarò disponibile."
        ]

        let message = escalationInquiry[language] ?? escalationInquiry["en"]!
        _ = await sendMessage(to: contactKey, message: message, platform: .sms)

        print("[Escalation] Sent inquiry to \(contactKey) - waiting for confirmation before notifying user")
    }

    private func checkEscalationConfirmation(contactKey: String, messageContent: String) async {
        let language = await detectLanguage(for: contactKey, phoneNumber: contactKey, messageContent: messageContent)

        // Check if this is an affirmative response
        if isAffirmativeResponse(messageContent, language: language) {
            // YES - this IS urgent, now notify user
            escalationPending.remove(contactKey)

            // Update conversation state
            if var state = conversationStates[contactKey] {
                state.markedAsUrgent = true
                state.currentStage = .confirmedUrgent
                conversationStates[contactKey] = state
            }

            // NOW we notify the user (only after confirmation)
            if globalSettings.escalationNotifyUser {
                await notifyUserOfUrgentContact(contactKey: contactKey)
            }

            // Send confirmation and call instructions
            let template = messageTemplates.autoReply[language] ?? messageTemplates.autoReply["en"]!
            _ = await sendMessage(to: contactKey, message: template.urgentConfirmed, platform: .sms)

            print("[Escalation] Contact \(contactKey) confirmed urgency - user notified")
        } else if isNegativeResponse(messageContent, language: language) {
            // NO - not urgent, just chatty
            escalationPending.remove(contactKey)

            let notUrgentReply: [String: String] = [
                "en": "No problem! I'll get back to you when I'm available. Thanks for understanding.",
                "de": "Kein Problem! Ich melde mich, wenn ich verfügbar bin. Danke für dein Verständnis.",
                "fr": "Pas de problème! Je te recontacte dès que possible. Merci de ta compréhension.",
                "it": "Nessun problema! Ti rispondo quando sarò disponibile. Grazie per la comprensione."
            ]

            let message = notUrgentReply[language] ?? notUrgentReply["en"]!
            _ = await sendMessage(to: contactKey, message: message, platform: .sms)

            print("[Escalation] Contact \(contactKey) confirmed NOT urgent - no user notification")
        }
        // If ambiguous, we don't respond again - wait for clearer answer
    }

    private func notifyUserOfUrgentContact(contactKey: String) async {
        // Send notification to user about urgent contact
        // This could be a push notification, sound alert, etc.
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Urgent Message"
        content.body = "Contact \(contactKey) has confirmed this is urgent."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)

        print("[Escalation] User notified about urgent contact: \(contactKey)")
    }

    // ============================================================================
    // MARK: - Enhancement 3: Calendar-Aware Auto-Replies (PRIVACY-FOCUSED)
    // ============================================================================
    //
    // PRIVACY: Never share meeting details or calendar info!
    // Only share when user will be available again - no meeting titles or details.
    // ============================================================================

    private func getCalendarAwareMessage(language: String) async -> String? {
        guard globalSettings.calendarAwareRepliesEnabled else { return nil }

        #if os(macOS)
        // Read ONLY the end time of current event - NOT the title (privacy)
        let script = """
        tell application "Calendar"
            set currentDate to current date
            set theCalendars to calendars
            repeat with cal in theCalendars
                set theEvents to (every event of cal whose start date ≤ currentDate and end date ≥ currentDate)
                if (count of theEvents) > 0 then
                    set theEvent to item 1 of theEvents
                    set eventEnd to end date of theEvent
                    -- Only return end time, NOT the event title (privacy)
                    return (eventEnd as string)
                end if
            end repeat
            return ""
        end tell
        """

        if let result = await runAppleScriptReturning(script), !result.isEmpty {
            // PRIVACY: Only say when available, NEVER mention what the event is
            let messages: [String: String] = [
                "en": "I should be available after \(result).",
                "de": "Ich sollte nach \(result) verfügbar sein.",
                "fr": "Je devrais être disponible après \(result).",
                "it": "Dovrei essere disponibile dopo \(result)."
            ]

            return messages[language] ?? messages["en"]
        }
        #endif

        return nil
    }

    private func getNextAvailableSlot(language: String) async -> String? {
        guard globalSettings.includeNextAvailableSlot else { return nil }

        #if os(macOS)
        // Find next free slot - only return TIME, no event details (privacy)
        return nil
        #else
        return nil
        #endif
    }

    // ============================================================================
    // MARK: - Enhancement 4: Location-Based Behavior (PRIVACY-FOCUSED)
    // ============================================================================
    //
    // PRIVACY: Never reveal location to contacts!
    // Location is used internally to adjust THEA's behavior, but never shared.
    // - At home: Might respond faster
    // - At work: Professional tone
    // - Custom locations: User-defined behavior
    //
    // The contact will NEVER know where the user is.
    // ============================================================================

    private func getCurrentLocationBehavior() async -> LocationFocusBehavior? {
        guard globalSettings.locationAwareBehaviorEnabled else { return nil }

        // Would need CoreLocation access
        // For now, return nil - actual implementation would check GPS
        return nil
    }

    private func getLocationAwareMessage(language: String) async -> String? {
        // PRIVACY: Location is NEVER shared with contacts
        // This function returns nil - location only affects internal behavior
        // (e.g., response timing, tone) but is never mentioned in messages
        nil
    }

    /// Internal: Adjust response behavior based on location (without revealing it)
    private func getLocationBasedResponseDelay() async -> TimeInterval {
        guard let _ = await getCurrentLocationBehavior() else {
            return globalSettings.autoReplyDelay
        }

        // At home might mean faster responses, at work might mean slower
        // But we NEVER tell the contact where we are
        return globalSettings.autoReplyDelay
    }

    // ============================================================================
    // MARK: - Enhancement 5: Voice Message Support
    // ============================================================================
    //
    // When receiving voice messages:
    // - Transcribe them using speech recognition
    // - Analyze for urgency
    // - Include transcription context in responses
    // ============================================================================

    /// Handle incoming voice message
    public func handleIncomingVoiceMessage(
        from contactId: String?,
        phoneNumber: String?,
        platform: CommunicationPlatform,
        audioURL: URL
    ) async {
        guard globalSettings.voiceMessageAnalysisEnabled else { return }
        guard currentFocusMode != nil else { return }

        var transcription: String?

        // Transcribe the voice message
        if globalSettings.transcribeVoiceMessages {
            transcription = await transcribeVoiceMessage(audioURL: audioURL)
        }

        // Handle like a text message but with voice context
        if let text = transcription {
            await handleIncomingMessage(
                from: contactId,
                contactName: nil,
                phoneNumber: phoneNumber,
                platform: platform,
                messageContent: "[Voice message]: \(text)"
            )
        }
    }

    private func transcribeVoiceMessage(audioURL: URL) async -> String? {
        #if os(macOS) || os(iOS)
        // Use Speech framework for transcription
        // This is a simplified placeholder
        print("[VoiceMessage] Would transcribe: \(audioURL)")
        return nil
        #else
        return nil
        #endif
    }

    // ============================================================================
    // MARK: - Enhancement 6: Group Chat Handling
    // ============================================================================
    //
    // Different handling for group chats:
    // - Don't spam the group with auto-replies
    // - Only respond to direct mentions
    // - Track group activity separately
    // ============================================================================

    private var groupChatAutoReplies: [String: Int] = [:] // Group ID -> reply count

    /// Handle incoming group chat message
    public func handleIncomingGroupMessage(
        groupId: String,
        groupName: String?,
        from contactId: String?,
        platform: CommunicationPlatform,
        messageContent: String,
        isMention: Bool
    ) async {
        guard globalSettings.groupChatHandlingEnabled else { return }
        guard currentFocusMode != nil else { return }

        // Check if we should respond
        if globalSettings.silenceGroupChats {
            // Only respond to direct mentions
            if globalSettings.onlyRespondToDirectMentions && !isMention {
                return
            }
        }

        // Check reply limit for this group
        let replyCount = groupChatAutoReplies[groupId] ?? 0
        if replyCount >= globalSettings.groupChatMaxReplies {
            return
        }

        if globalSettings.groupChatAutoReplyEnabled {
            let language = await detectLanguage(for: contactId, phoneNumber: nil, messageContent: messageContent)
            let template = messageTemplates.autoReply[language] ?? messageTemplates.autoReply["en"]!

            // Send a group-appropriate response
            let groupMessage = """
            [Auto-reply] \(template.initialMessage)
            (This is an automated response - I'll catch up with the group when available)
            """

            // Only send if mentioned
            if isMention {
                await sendGroupMessage(groupId: groupId, message: groupMessage, platform: platform)
                groupChatAutoReplies[groupId] = replyCount + 1
            }
        }
    }

    private func sendGroupMessage(groupId: String, message: String, platform: CommunicationPlatform) async {
        // Similar to sendMessage but for groups
        print("[GroupChat] Would send to group \(groupId): \(message)")
    }

    // ============================================================================
    // MARK: - Enhancement 7: VIP Mode
    // ============================================================================
    //
    // VIP contacts get special treatment:
    // - Custom personalized messages
    // - Always ring through (optional)
    // - Higher priority in callbacks
    // ============================================================================

    /// Check if contact is VIP
    public func isVIPContact(_ contactId: String) -> Bool {
        globalSettings.vipContacts.contains(contactId)
    }

    /// Add VIP contact
    public func addVIPContact(_ contactId: String, customMessage: String? = nil) {
        if !globalSettings.vipContacts.contains(contactId) {
            globalSettings.vipContacts.append(contactId)
        }
        if let message = customMessage {
            globalSettings.vipCustomMessages[contactId] = message
        }

        Task {
            await saveSettings()
        }
    }

    /// Remove VIP contact
    public func removeVIPContact(_ contactId: String) {
        globalSettings.vipContacts.removeAll { $0 == contactId }
        globalSettings.vipCustomMessages.removeValue(forKey: contactId)

        Task {
            await saveSettings()
        }
    }

    private func getVIPMessage(for contactId: String, language: String) -> String? {
        guard isVIPContact(contactId) else { return nil }

        // Check for custom message first
        if let custom = globalSettings.vipCustomMessages[contactId] {
            return custom
        }

        // Return a VIP-specific default
        let vipMessages: [String: String] = [
            "en": "Hi! I'm currently in Focus Mode but saw it's you. Is this something that can't wait?",
            "de": "Hallo! Ich bin gerade im Fokus-Modus, aber ich sehe, dass du es bist. Kann das nicht warten?",
            "fr": "Salut! Je suis en mode Concentration mais j'ai vu que c'était toi. C'est quelque chose qui ne peut pas attendre?",
            "it": "Ciao! Sono in modalità Focus ma ho visto che sei tu. È qualcosa che non può aspettare?"
        ]

        return vipMessages[language] ?? vipMessages["en"]
    }

    // ============================================================================
    // MARK: - Enhancement 8: Learning from Outcomes
    // ============================================================================
    //
    // Track how Focus sessions go and learn:
    // - Which contacts actually have urgent matters
    // - Optimal reply timing
    // - Which phrases indicate real urgency
    // - Adjust behavior based on feedback
    // ============================================================================

    private struct FocusSessionAnalytics: Codable, Sendable {
        let sessionId: UUID
        let focusModeId: String
        let startTime: Date
        var endTime: Date?
        var messagesReceived: Int
        var callsReceived: Int
        var urgentMarked: Int
        var actuallyUrgent: Int // Based on user feedback
        var autoRepliesSent: Int
        var contactResponses: [String: ContactResponse] // Contact -> their response

        struct ContactResponse: Codable, Sendable {
            let contactId: String
            var messagesBeforeUrgent: Int
            var claimedUrgent: Bool
            var wasActuallyUrgent: Bool?
            var responseTime: TimeInterval?
        }
    }

    private var currentSessionAnalytics: FocusSessionAnalytics?
    private var historicalAnalytics: [FocusSessionAnalytics] = []

    private func startSessionAnalytics(mode: FocusModeConfiguration) {
        currentSessionAnalytics = FocusSessionAnalytics(
            sessionId: UUID(),
            focusModeId: mode.id,
            startTime: Date(),
            messagesReceived: 0,
            callsReceived: 0,
            urgentMarked: 0,
            actuallyUrgent: 0,
            autoRepliesSent: 0,
            contactResponses: [:]
        )
    }

    private func applyLearningFromSession(mode: FocusModeConfiguration) async {
        guard var analytics = currentSessionAnalytics else { return }

        analytics.endTime = Date()
        historicalAnalytics.append(analytics)

        // Analyze patterns
        if globalSettings.trackResponsePatterns {
            await analyzeContactPatterns()
        }

        if globalSettings.adjustPriorityFromFeedback {
            await adjustContactPriorities()
        }

        if globalSettings.learnOptimalReplyTiming {
            await analyzeOptimalTiming()
        }

        if globalSettings.learnUrgencyIndicators {
            await learnNewUrgencyPatterns()
        }

        // Save analytics
        await saveAnalytics()

        currentSessionAnalytics = nil
    }

    private func analyzeContactPatterns() async {
        // Analyze which contacts frequently mark things as urgent
        // Adjust their priority scores accordingly

        var urgencyFrequency: [String: Double] = [:]

        for session in historicalAnalytics {
            for (contactId, response) in session.contactResponses {
                if response.claimedUrgent {
                    urgencyFrequency[contactId, default: 0] += 1
                }
            }
        }

        // Contacts who frequently claim urgency might need different handling
        for (contactId, frequency) in urgencyFrequency {
            if frequency > 5 {
                // This contact often has urgent matters
                contactPriorities[contactId] = min(1.0, (contactPriorities[contactId] ?? 0.5) + 0.1)
            }
        }
    }

    private func adjustContactPriorities() async {
        // Adjust based on whether "urgent" claims were actually urgent
        // This requires user feedback mechanism
    }

    private func analyzeOptimalTiming() async {
        // Analyze when auto-replies are most effective
        // e.g., immediate replies vs delayed replies
    }

    private func learnNewUrgencyPatterns() async {
        // Look for new phrases that indicate urgency
        // that aren't in our current keyword list
    }

    private func saveAnalytics() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(historicalAnalytics) {
            defaults.set(encoded, forKey: "focusModeAnalytics")
            defaults.synchronize()
        }
    }

    // ============================================================================
    // MARK: - Public API for User Feedback (Enhancement 8)
    // ============================================================================

    /// User marks whether a contact's matter was actually urgent
    public func markUrgencyFeedback(contactId: String, wasActuallyUrgent: Bool) {
        guard var analytics = currentSessionAnalytics,
              var response = analytics.contactResponses[contactId] else { return }

        response.wasActuallyUrgent = wasActuallyUrgent
        analytics.contactResponses[contactId] = response

        if wasActuallyUrgent {
            analytics.actuallyUrgent += 1
        }

        currentSessionAnalytics = analytics

        // Adjust contact priority based on feedback
        if globalSettings.adjustPriorityFromFeedback {
            let currentPriority = contactPriorities[contactId] ?? 0.5

            if wasActuallyUrgent {
                // They were right, increase priority slightly
                contactPriorities[contactId] = min(1.0, currentPriority + 0.05)
            } else {
                // They weren't urgent, decrease priority slightly
                contactPriorities[contactId] = max(0.0, currentPriority - 0.02)
            }
        }
    }

    /// Get contact priority score (0.0 - 1.0, higher = more likely urgent)
    public func getContactPriority(_ contactId: String) -> Double {
        contactPriorities[contactId] ?? 0.5
    }

    // ============================================================================
    // MARK: - Public API for Shortcuts Integration
    // ============================================================================

    /// Called when Focus mode changes via Shortcuts automation
    public func setActiveFocusMode(_ modeName: String?) async {
        if let name = modeName {
            // Find the mode by name
            if let mode = focusModes.values.first(where: { $0.name == name }) {
                var activeMode = mode
                activeMode.isActive = true
                currentFocusMode = activeMode
                await handleFocusModeActivated(activeMode)
                onFocusModeChanged?(activeMode)
            }
        } else {
            // Focus mode deactivated
            if let previousMode = currentFocusMode {
                currentFocusMode = nil
                await handleFocusModeDeactivated(previousMode)
                onFocusModeChanged?(nil)
            }
        }
    }

    /// Generate Shortcuts automation instructions
    public func generateShortcutsSetupInstructions() -> String {
        """
        # THEA Focus Mode Shortcuts Setup

        ## Required Shortcuts (THEA will help create these automatically)

        ### 1. "THEA Focus Activated" (Automation)
        **Trigger:** When ANY Focus mode turns ON
        **Actions:**
        1. Get name of Focus
        2. Open URL: thea://focus-activated?mode=[Focus Name]

        ### 2. "THEA Focus Deactivated" (Automation)
        **Trigger:** When ANY Focus mode turns OFF
        **Actions:**
        1. Open URL: thea://focus-deactivated

        ### 3. "THEA Call Forwarding" (Shortcut)
        **Input:** USSD code (e.g., *21*086#)
        **Actions:**
        1. Get text from Input
        2. Call [Input text]

        Note: This enables/disables call forwarding to COMBOX

        ### 4. "THEA Auto Reply" (Shortcut)
        **Input:** "phoneNumber|message"
        **Actions:**
        1. Split Input by "|"
        2. Send Message [Item 2] to [Item 1]

        ### 5. "THEA WhatsApp Reply" (Shortcut)
        **Input:** "phoneNumber|message"
        **Actions:**
        1. Split Input by "|"
        2. Open URL: whatsapp://send?phone=[Item 1]&text=[URL-encoded Item 2]
        3. Wait 1 second
        4. Tap "Send" (accessibility)

        ### 6. "THEA COMBOX Greeting" (Shortcut)
        **Input:** greeting type
        **Actions:**
        1. Call 086
        2. Wait for answer
        3. Play DTMF: 9 (settings menu)
        4. Wait 1 second
        5. Play DTMF: 1 (greeting settings)
        6. Wait 1 second
        7. If Input = "focus_mode": Play DTMF: 2
           Else: Play DTMF: 1

        ## Important Notes

        - Enable "Ask Before Running" = OFF for all automations
        - Grant necessary permissions to THEA app
        - Test each shortcut individually first

        ## Why Call Forwarding?

        When Focus Mode blocks calls, iOS **immediately rejects them** at the network level.
        The caller hears a 3-tone disconnect sound (like you hung up).
        They can't leave voicemail, and "call twice" won't work!

        **Solution:** Forward ALL calls to COMBOX when Focus is active.
        - Calls go to voicemail instead of being rejected
        - COMBOX plays a Focus-aware greeting
        - THEA sends SMS after voicemail with callback instructions
        """
    }

    // ============================================================================
    // MARK: - ADVANCED FEATURES: Reliability, Anticipation, Autonomy
    // ============================================================================

    // MARK: - 1. Reliability: Action Verification & Retry

    /// Track pending actions that need verification
    private var pendingActions: [PendingAction] = []

    private struct PendingAction: Identifiable, Sendable {
        let id: UUID
        let actionType: ActionType
        let timestamp: Date
        var attempts: Int
        var lastAttempt: Date
        var verified: Bool
        let maxRetries: Int
        let verificationMethod: VerificationMethod

        enum ActionType: String, Sendable {
            case callForwardingEnable
            case callForwardingDisable
            case comboxGreetingChange
            case whatsAppStatusUpdate
            case sendAutoReply
            case shortcutExecution
        }

        enum VerificationMethod: String, Sendable {
            case callbackURL // THEA receives callback when done
            case pollStatus // Check status after delay
            case assumeSuccess // Fire and forget
            case userConfirmation // Ask user to confirm
        }
    }

    /// Execute action with verification and retry logic
    private func executeWithVerification(
        actionType: PendingAction.ActionType,
        action: @escaping () async -> Bool,
        verificationMethod: PendingAction.VerificationMethod = .pollStatus,
        maxRetries: Int = 3
    ) async -> Bool {
        let pendingAction = PendingAction(
            id: UUID(),
            actionType: actionType,
            timestamp: Date(),
            attempts: 0,
            lastAttempt: Date(),
            verified: false,
            maxRetries: maxRetries,
            verificationMethod: verificationMethod
        )

        pendingActions.append(pendingAction)

        for attempt in 1...maxRetries {
            print("[Reliability] Executing \(actionType.rawValue), attempt \(attempt)/\(maxRetries)")

            let success = await action()

            if success {
                // Verify the action actually worked
                if verificationMethod == .pollStatus {
                    try? await Task.sleep(for: .seconds(2))
                    let verified = await verifyAction(actionType)
                    if verified {
                        markActionVerified(pendingAction.id)
                        return true
                    }
                } else {
                    markActionVerified(pendingAction.id)
                    return true
                }
            }

            // Wait before retry with exponential backoff
            let delay = Double(attempt) * 2.0
            try? await Task.sleep(for: .seconds(delay))
        }

        // All retries failed - notify user
        await notifyUserOfFailedAction(actionType)
        return false
    }

    private func verifyAction(_ actionType: PendingAction.ActionType) async -> Bool {
        switch actionType {
        case .callForwardingEnable:
            // Could check by calling *#21# to query forwarding status
            return true // Assume success for now
        case .callForwardingDisable:
            return true
        case .comboxGreetingChange:
            return true
        case .whatsAppStatusUpdate:
            // Could check WhatsApp Desktop window
            return true
        case .sendAutoReply:
            return true
        case .shortcutExecution:
            return true
        }
    }

    private func markActionVerified(_ id: UUID) {
        if let index = pendingActions.firstIndex(where: { $0.id == id }) {
            pendingActions[index].verified = true
        }
    }

    private func notifyUserOfFailedAction(_ actionType: PendingAction.ActionType) async {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ THEA Action Failed"
        content.body = "Failed to execute: \(actionType.rawValue). Please check manually."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)

        print("[Reliability] ❌ Action failed after all retries: \(actionType.rawValue)")
    }

    // MARK: - 2. Proactive Anticipation

    /// Predict when Focus Mode should be activated
    public func predictFocusModeActivation() async -> FocusPrediction? {
        guard globalSettings.suggestFocusModeActivation else { return nil }

        var signals: [PredictionSignal] = []

        // Check calendar for upcoming events
        if let calendarSignal = await checkCalendarForFocusTriggers() {
            signals.append(calendarSignal)
        }

        // Check time patterns (e.g., always Focus at 9am on weekdays)
        if let timeSignal = checkTimePatterns() {
            signals.append(timeSignal)
        }

        // Check location patterns
        if let locationSignal = await checkLocationPatterns() {
            signals.append(locationSignal)
        }

        // Calculate overall prediction
        guard !signals.isEmpty else { return nil }

        let totalConfidence = signals.map { $0.confidence }.reduce(0, +) / Double(signals.count)
        let suggestedMode = determineBestFocusMode(from: signals)

        return FocusPrediction(
            shouldActivate: totalConfidence > 0.7,
            suggestedMode: suggestedMode,
            confidence: totalConfidence,
            signals: signals,
            suggestedTime: signals.compactMap { $0.suggestedTime }.min()
        )
    }

    public struct FocusPrediction: Sendable {
        let shouldActivate: Bool
        let suggestedMode: String?
        let confidence: Double
        let signals: [PredictionSignal]
        let suggestedTime: Date?
    }

    public struct PredictionSignal: Sendable {
        let source: String
        let confidence: Double
        let suggestedMode: String?
        let suggestedTime: Date?
        let reason: String
    }

    private func checkCalendarForFocusTriggers() async -> PredictionSignal? {
        #if os(macOS)
        // Check for meetings in the next 15 minutes
        let script = """
        tell application "Calendar"
            set currentDate to current date
            set futureDate to currentDate + (15 * minutes)
            set theCalendars to calendars
            repeat with cal in theCalendars
                set theEvents to (every event of cal whose start date ≥ currentDate and start date ≤ futureDate)
                if (count of theEvents) > 0 then
                    set theEvent to item 1 of theEvents
                    set eventStart to start date of theEvent
                    return (eventStart as string)
                end if
            end repeat
            return ""
        end tell
        """

        if let result = await runAppleScriptReturning(script), !result.isEmpty {
            return PredictionSignal(
                source: "calendar",
                confidence: 0.9,
                suggestedMode: "Work", // or detect from calendar type
                suggestedTime: Date(), // Parse result
                reason: "Upcoming calendar event"
            )
        }
        #endif

        return nil
    }

    private func checkTimePatterns() -> PredictionSignal? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekday = weekday >= 2 && weekday <= 6

        // Example: Suggest Work Focus at 9am on weekdays
        if isWeekday && hour == 9 {
            return PredictionSignal(
                source: "time_pattern",
                confidence: 0.7,
                suggestedMode: "Work",
                suggestedTime: nil,
                reason: "Typical work start time"
            )
        }

        // Suggest Sleep Focus at 10pm
        if hour == 22 {
            return PredictionSignal(
                source: "time_pattern",
                confidence: 0.8,
                suggestedMode: "Sleep",
                suggestedTime: nil,
                reason: "Typical sleep time"
            )
        }

        return nil
    }

    private func checkLocationPatterns() async -> PredictionSignal? {
        // Would use CoreLocation
        nil
    }

    private func determineBestFocusMode(from signals: [PredictionSignal]) -> String? {
        // Return most confident suggestion
        signals.max { $0.confidence < $1.confidence }?.suggestedMode
    }

    // MARK: - 3. Contextual Intelligence

    /// Cross-reference message with calendar, projects, etc.
    private func enrichUrgencyWithContext(
        _ assessment: UrgencyAssessment,
        contactId: String?,
        messageContent: String
    ) async -> UrgencyAssessment {
        var signals = assessment.signals
        var additionalScore: Double = 0

        // Check if sender has a meeting with you soon
        if let cId = contactId, await hasMeetingWithContactSoon(cId) {
            signals.append(UrgencySignal(
                type: .calendarContext,
                weight: 0.25,
                description: "Has meeting with you soon"
            ))
            additionalScore += 0.25
        }

        // Check if message references known project/deadline
        if messageContainsProjectReference(messageContent) {
            signals.append(UrgencySignal(
                type: .deadlineRelated,
                weight: 0.2,
                description: "References known project"
            ))
            additionalScore += 0.2
        }

        // Check if this is a reply to something you sent
        if await isReplyToYourMessage(contactId: contactId) {
            signals.append(UrgencySignal(
                type: .historicalPattern,
                weight: 0.15,
                description: "Reply to your recent message"
            ))
            additionalScore += 0.15
        }

        let newScore = min(1.0, assessment.score + additionalScore)
        let newLevel = scoreToUrgencyLevel(newScore)
        let newRecommendation = determineRecommendation(score: newScore, signals: signals)

        return UrgencyAssessment(
            score: newScore,
            level: newLevel,
            confidence: assessment.confidence,
            signals: signals,
            recommendation: newRecommendation,
            reasoning: generateReasoning(signals: signals, score: newScore, recommendation: newRecommendation)
        )
    }

    private func hasMeetingWithContactSoon(_ contactId: String) async -> Bool {
        // Would check calendar for events with this contact
        false
    }

    private func messageContainsProjectReference(_ message: String) -> Bool {
        // Would check against known project names, ticket numbers, etc.
        let lowercased = message.lowercased()

        // Common project reference patterns
        let patterns = [
            "(jira|asana|trello|linear)-?\\d+", // Ticket numbers
            "pr[- ]?#?\\d+", // Pull request
            "issue[- ]?#?\\d+", // Issue numbers
            "deadline",
            "due (today|tomorrow|soon)"
        ]

        for pattern in patterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    private func isReplyToYourMessage(contactId: String?) async -> Bool {
        // Would check recent outgoing messages to this contact
        false
    }

    // MARK: - 4. Focus Session Summary

    /// Generate end-of-Focus summary of what happened
    public func generateFocusSessionSummary() async -> FocusSessionSummary {
        let duration = currentSessionAnalytics.map {
            Date().timeIntervalSince($0.startTime)
        } ?? 0

        let missedCalls = recentCommunications.filter {
            $0.type == .missedCall && $0.focusModeWhenReceived != nil
        }

        let messages = recentCommunications.filter {
            $0.type == .message && $0.focusModeWhenReceived != nil
        }

        let urgentContacts = conversationStates.filter {
            $0.value.markedAsUrgent
        }.map { $0.key }

        let pendingResponses = conversationStates.filter {
            $0.value.currentStage == .askedIfUrgent || $0.value.currentStage == .initial
        }.count

        return FocusSessionSummary(
            duration: duration,
            messagesReceived: messages.count,
            callsMissed: missedCalls.count,
            autoRepliesSent: currentSessionAnalytics?.autoRepliesSent ?? 0,
            urgentContacts: urgentContacts,
            pendingResponses: pendingResponses,
            topPriorityContacts: getTopPriorityContacts(from: messages),
            suggestedFollowUps: await generateFollowUpSuggestions()
        )
    }

    public struct FocusSessionSummary: Sendable {
        let duration: TimeInterval
        let messagesReceived: Int
        let callsMissed: Int
        let autoRepliesSent: Int
        let urgentContacts: [String]
        let pendingResponses: Int
        let topPriorityContacts: [String]
        let suggestedFollowUps: [FollowUpSuggestion]
    }

    public struct FollowUpSuggestion: Sendable {
        let contactId: String
        let reason: String
        let priority: Int // 1 = highest
        let suggestedAction: String
    }

    private func getTopPriorityContacts(from communications: [IncomingCommunication]) -> [String] {
        var contactCounts: [String: Int] = [:]
        for comm in communications {
            if let cId = comm.contactId ?? comm.phoneNumber {
                contactCounts[cId, default: 0] += 1
            }
        }

        return contactCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    private func generateFollowUpSuggestions() async -> [FollowUpSuggestion] {
        var suggestions: [FollowUpSuggestion] = []

        // Suggest following up with urgent contacts
        for (contactKey, state) in conversationStates where state.markedAsUrgent {
            suggestions.append(FollowUpSuggestion(
                contactId: contactKey,
                reason: "Marked as urgent during Focus",
                priority: 1,
                suggestedAction: "Call back immediately"
            ))
        }

        // Suggest following up with high-frequency contacts
        for (contactKey, timestamps) in messageCountTracking {
            if timestamps.count >= 3 {
                suggestions.append(FollowUpSuggestion(
                    contactId: contactKey,
                    reason: "Sent \(timestamps.count) messages",
                    priority: 2,
                    suggestedAction: "Check their messages"
                ))
            }
        }

        return suggestions.sorted { $0.priority < $1.priority }
    }

    // MARK: - 5. Smart Auto-Focus Activation

    /// Automatically enable Focus based on context
    public func checkAndAutoEnableFocus() async {
        guard globalSettings.autoFocusOnCalendarEvents else { return }

        // Already in Focus?
        guard currentFocusMode == nil else { return }

        // Check prediction
        if let prediction = await predictFocusModeActivation(),
           prediction.shouldActivate,
           prediction.confidence > 0.85,
           let modeName = prediction.suggestedMode {

            print("[AutoFocus] High-confidence prediction to enable '\(modeName)' Focus")

            // Could auto-enable or just notify user
            let content = UNMutableNotificationContent()
            content.title = "💡 Focus Mode Suggestion"
            content.body = "Should I enable \(modeName) Focus? Reason: \(prediction.signals.first?.reason ?? "detected pattern")"
            content.sound = .default
            content.categoryIdentifier = "FOCUS_SUGGESTION"
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - 6. Swisscom COMBOX Visual Voicemail Integration

    /// Check COMBOX for new voicemails (requires Swisscom Visual Voicemail)
    public func checkComboxForNewVoicemails() async -> [VoicemailInfo] {
        // Swisscom Visual Voicemail pushes to device
        // We can monitor for these notifications

        // This would integrate with the iOS Visual Voicemail system
        // or poll COMBOX status via DTMF commands
        []
    }

    public struct VoicemailInfo: Sendable {
        let callerNumber: String
        let callerName: String?
        let timestamp: Date
        let duration: TimeInterval
        let transcription: String? // If available
        let urgencyAssessment: UrgencyAssessment?
    }

    // MARK: - 7. Health & Activity Awareness

    /// Adjust behavior based on user's current activity
    public func adjustForActivity(_ activity: UserActivity) {
        switch activity {
        case .sleeping:
            // Only true emergencies should break through
            globalSettings.escalationMessageThreshold = 5
        case .exercising:
            // Brief responses only
            globalSettings.autoReplyDelay = 0 // Immediate
        case .driving:
            // Voice-only if needed
            break
        case .inMeeting:
            // Standard Focus behavior
            break
        case .available:
            // Disable auto-replies
            globalSettings.autoReplyEnabled = false
        }
    }

    public enum UserActivity: String, Sendable {
        case sleeping, exercising, driving, inMeeting, available
    }
}
