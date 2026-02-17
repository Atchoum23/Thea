// LifeMonitoringCoordinator.swift
// Thea V2 - Comprehensive Life Monitoring System
//
// Central coordinator for all life monitoring data sources:
// - Browser activity (via extensions)
// - Clipboard monitoring
// - Messages (chat.db)
// - Mail
// - File system activity
// - App usage (macOS)
// - Health data (iOS/watchOS)
// - Location (iOS)
//
// All data flows through this coordinator to:
// - MemoryManager (for learning and context)
// - ProactivityEngine (for intelligent suggestions)
// - AI analysis pipeline (for insights)

import Combine
import Foundation
import os.log

// MARK: - Life Monitoring Coordinator

/// Central hub for THEA's life monitoring system
@MainActor
public final class LifeMonitoringCoordinator: ObservableObject {
    public static let shared = LifeMonitoringCoordinator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "LifeMonitoring")

    // MARK: - Published State

    @Published public private(set) var isMonitoringEnabled = true
    @Published public private(set) var activeDataSources: Set<DataSourceType> = []
    @Published public private(set) var lastEventTime: Date?
    @Published public private(set) var todayEventCount = 0
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected

    // MARK: - Data Source References

    // Browser activity is tracked via SafariContextExtractor and GenericContextExtractor
    // in the AppPairing system rather than a dedicated BrowserActivityMonitor
    #if os(macOS)
    private var clipboardMonitor: ClipboardMonitor?
    private var messagesMonitor: MessagesMonitor?
    private var mailMonitor: MailMonitor?
    private var fileSystemMonitor: FileSystemMonitor?
    #endif

    // V2 Comprehensive monitors
    private var socialMediaMonitor: SocialMediaMonitor?
    private var appUsageMonitor: AppUsageMonitor?
    private var interactionTracker: InteractionTracker?

    // V2.1 Extended monitors
    private var calendarMonitor: CalendarMonitor?
    private var remindersMonitor: RemindersMonitor?
    private var homeKitMonitor: HomeKitMonitor?
    private var shortcutsMonitor: ShortcutsMonitor?
    private var mediaMonitor: MediaMonitor?
    private var photosMonitor: PhotosMonitor?
    private var notificationMonitor: NotificationMonitor?
    private var documentEditingMonitor: DocumentEditingMonitor?
    private var inputActivityMonitor: InputActivityMonitor?
    private var behaviorPatternAnalyzer: BehaviorPatternAnalyzer?
    private var efficiencySuggestionEngine: EfficiencySuggestionEngine?

    // V2.2 AI-Powered Intelligence (these are singletons, we just reference them)
    // - HolisticPatternIntelligence: Deep pattern recognition across all life aspects
    // - PredictiveLifeEngine: Anticipatory intelligence and proactive suggestions

    // MARK: - WebSocket Server

    private var webSocketServer: LifeMonitorWebSocketServer?

    // MARK: - Event Stream

    private let eventSubject = PassthroughSubject<LifeEvent, Never>()
    public var eventStream: AnyPublisher<LifeEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    public var configuration = LifeMonitoringConfiguration()

    // MARK: - Cloud Sync

    private var cloudSync: LifeMonitoringCloudSync?
    private var cloudSyncTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        logger.info("LifeMonitoringCoordinator initialized")
        setupEventProcessing()
        setupCloudSyncObservers()
    }

    // MARK: - Lifecycle

    /// Start all configured monitoring services
    public func startMonitoring() async {
        guard isMonitoringEnabled else {
            logger.warning("Monitoring is disabled")
            return
        }

        logger.info("Starting life monitoring services...")

        // Start WebSocket server for browser extension communication
        await startWebSocketServer()

        // Start platform-specific monitors
        #if os(macOS)
            await startMacOSMonitors()
        #endif

        #if os(iOS) || os(watchOS)
            await startIOSMonitors()
        #endif

        // Start comprehensive monitors (all platforms)
        await startComprehensiveMonitors()

        connectionStatus = .connected

        // Start cloud sync
        await startCloudSync()

        // Start AI analysis pipeline
        if configuration.aiAnalysisEnabled {
            LifeInsightsAnalyzer.shared.start()
        }

        logger.info("Life monitoring started with \(self.activeDataSources.count) data sources")
    }

    /// Stop all monitoring services
    public func stopMonitoring() async {
        logger.info("Stopping life monitoring services...")

        // Flush pending cloud sync before stopping
        try? await cloudSync?.flushPendingEvents()
        cloudSyncTask?.cancel()

        // Stop AI analysis pipeline
        LifeInsightsAnalyzer.shared.stop()

        // Stop WebSocket and legacy monitors
        await webSocketServer?.stop()
        #if os(macOS)
        await clipboardMonitor?.stop()
        await messagesMonitor?.stop()
        await mailMonitor?.stop()
        await fileSystemMonitor?.stop()
        #endif

        // Stop comprehensive monitors
        await socialMediaMonitor?.stop()
        await appUsageMonitor?.stop()
        await interactionTracker?.stop()

        // Stop V2.1 extended monitors
        await calendarMonitor?.stop()
        await remindersMonitor?.stop()
        await homeKitMonitor?.stop()
        await shortcutsMonitor?.stop()
        await mediaMonitor?.stop()
        await photosMonitor?.stop()
        await notificationMonitor?.stop()
        await documentEditingMonitor?.stop()
        inputActivityMonitor?.stopMonitoring()
        behaviorPatternAnalyzer?.stop()
        efficiencySuggestionEngine?.stop()

        // Stop V2.2 AI intelligence systems
        HolisticPatternIntelligence.shared.stop()
        PredictiveLifeEngine.shared.stop()

        activeDataSources.removeAll()
        connectionStatus = .disconnected

        logger.info("Life monitoring stopped")
    }

    // MARK: - WebSocket Server

    private func startWebSocketServer() async {
        webSocketServer = LifeMonitorWebSocketServer(port: 9876)
        await webSocketServer?.setDelegate(self)

        do {
            try await webSocketServer?.start()
            activeDataSources.insert(.browserExtension)
            logger.info("WebSocket server started on port 9876")
        } catch {
            logger.error("Failed to start WebSocket server: \(error.localizedDescription)")
        }
    }

    // MARK: - macOS Monitors

    #if os(macOS)
        private func startMacOSMonitors() async {
            // Clipboard monitoring
            if configuration.clipboardMonitoringEnabled {
                clipboardMonitor = ClipboardMonitor()
                await clipboardMonitor?.setDelegate(self)
                await clipboardMonitor?.start()
                activeDataSources.insert(.clipboard)
            }

            // Messages monitoring (chat.db)
            if configuration.messagesMonitoringEnabled {
                messagesMonitor = MessagesMonitor()
                await messagesMonitor?.setDelegate(self)
                await messagesMonitor?.start()
                activeDataSources.insert(.messages)
            }

            // Mail monitoring
            if configuration.mailMonitoringEnabled {
                mailMonitor = MailMonitor()
                await mailMonitor?.setDelegate(self)
                await mailMonitor?.start()
                activeDataSources.insert(.mail)
            }

            // File system monitoring
            if configuration.fileSystemMonitoringEnabled {
                fileSystemMonitor = FileSystemMonitor(
                    watchPaths: configuration.watchedDirectories
                )
                fileSystemMonitor?.delegate = self
                await fileSystemMonitor?.start()
                activeDataSources.insert(.fileSystem)
            }
        }
    #endif

    // MARK: - iOS Monitors

    #if os(iOS) || os(watchOS)
        private func startIOSMonitors() async {
            // iOS-specific monitoring is handled by:
            // - HealthKitService (health data)
            // - LocationTrackingManager (location)
            // - These already integrate with the system

            // Register as data sources
            activeDataSources.insert(.health)
            activeDataSources.insert(.location)
        }
    #endif

    // MARK: - Comprehensive Monitors (All Platforms)

    /// Start comprehensive monitoring for social media, app usage, and interactions
    private func startComprehensiveMonitors() async {
        // Social Media Monitoring
        if configuration.socialMediaMonitoringEnabled {
            socialMediaMonitor = SocialMediaMonitor.shared
            await socialMediaMonitor?.start()
            activeDataSources.insert(.socialMedia)
            logger.info("Social media monitoring started")
        }

        // App Usage Monitoring
        if configuration.appUsageMonitoringEnabled {
            appUsageMonitor = AppUsageMonitor.shared
            await appUsageMonitor?.start()
            activeDataSources.insert(.appUsage)
            logger.info("App usage monitoring started")
        }

        // Interaction Tracking (aggregates all people/company interactions)
        if configuration.interactionTrackingEnabled {
            interactionTracker = InteractionTracker.shared
            await interactionTracker?.start()
            activeDataSources.insert(.interactions)
            logger.info("Interaction tracking started")
        }

        // Calendar Monitoring
        if configuration.calendarMonitoringEnabled {
            calendarMonitor = CalendarMonitor.shared
            await calendarMonitor?.start()
            activeDataSources.insert(.calendar)
            logger.info("Calendar monitoring started")
        }

        // Reminders Monitoring
        if configuration.remindersMonitoringEnabled {
            remindersMonitor = RemindersMonitor.shared
            await remindersMonitor?.start()
            activeDataSources.insert(.reminders)
            logger.info("Reminders monitoring started")
        }

        // HomeKit Monitoring
        if configuration.homeKitMonitoringEnabled {
            homeKitMonitor = HomeKitMonitor.shared
            await homeKitMonitor?.start()
            activeDataSources.insert(.homeKit)
            logger.info("HomeKit monitoring started")
        }

        // Shortcuts Monitoring
        if configuration.shortcutsMonitoringEnabled {
            shortcutsMonitor = ShortcutsMonitor.shared
            await shortcutsMonitor?.start()
            activeDataSources.insert(.shortcuts)
            logger.info("Shortcuts monitoring started")
        }

        // Media Monitoring (Music, Video, Streaming)
        if configuration.mediaMonitoringEnabled {
            mediaMonitor = MediaMonitor.shared
            await mediaMonitor?.start()
            activeDataSources.insert(.media)
            logger.info("Media monitoring started")
        }

        // Photos Monitoring
        if configuration.photosMonitoringEnabled {
            photosMonitor = PhotosMonitor.shared
            await photosMonitor?.start()
            activeDataSources.insert(.photos)
            logger.info("Photos monitoring started")
        }

        // Notification Monitoring
        if configuration.notificationMonitoringEnabled {
            notificationMonitor = NotificationMonitor.shared
            await notificationMonitor?.start()
            activeDataSources.insert(.notifications)
            logger.info("Notification monitoring started")
        }

        // Document Editing Monitoring (TextEdit, Notes, etc.)
        if configuration.documentEditingMonitoringEnabled {
            documentEditingMonitor = DocumentEditingMonitor.shared
            await documentEditingMonitor?.start()
            activeDataSources.insert(.documentEditing)
            logger.info("Document editing monitoring started")
        }

        // Input Activity Monitoring (mouse, keyboard, typing patterns)
        if configuration.inputActivityMonitoringEnabled {
            inputActivityMonitor = InputActivityMonitor.shared
            inputActivityMonitor?.startMonitoring()
            activeDataSources.insert(.inputActivity)
            logger.info("Input activity monitoring started")
        }

        // Behavior Pattern Analysis (detects repetitive actions, productivity patterns)
        if configuration.behaviorPatternAnalysisEnabled {
            behaviorPatternAnalyzer = BehaviorPatternAnalyzer.shared
            behaviorPatternAnalyzer?.start()
            logger.info("Behavior pattern analysis started")
        }

        // Efficiency Suggestion Engine (proactive suggestions based on patterns)
        if configuration.efficiencySuggestionsEnabled {
            efficiencySuggestionEngine = EfficiencySuggestionEngine.shared
            efficiencySuggestionEngine?.start()
            logger.info("Efficiency suggestion engine started")
        }

        // V2.2 AI-Powered Intelligence Systems
        // These are singletons that subscribe to our event stream automatically
        if configuration.holisticPatternIntelligenceEnabled {
            HolisticPatternIntelligence.shared.start()
            logger.info("Holistic pattern intelligence started")
        }

        if configuration.predictiveEngineEnabled {
            PredictiveLifeEngine.shared.start()
            logger.info("Predictive life engine started")
        }
    }

    // MARK: - Event Processing

    private func setupEventProcessing() {
        // Process incoming events
        eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task {
                    await self?.processEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    private func processEvent(_ event: LifeEvent) async {
        lastEventTime = event.timestamp
        todayEventCount += 1

        // 1. Store in memory system
        await storeInMemory(event)

        // 2. Run AI analysis if significant
        if event.significance >= .moderate {
            await analyzeWithAI(event)
        }

        // 3. Check for proactive opportunities
        await checkProactiveOpportunities(event)

        // 4. Publish to EventBus for UI updates
        publishToEventBus(event)

        // 5. Queue for iCloud sync (significant events only to save bandwidth)
        if event.significance >= .minor {
            queueForCloudSync(event)
        }
    }

    private func storeInMemory(_ event: LifeEvent) async {
        // Store as episodic memory
        await MemoryManager.shared.storeEpisodicMemory(
            event: event.type.rawValue,
            context: event.summary,
            outcome: nil,
            emotionalValence: event.sentiment
        )

        // Extract and store semantic knowledge if applicable
        if let entities = event.extractedEntities {
            for entity in entities {
                await MemoryManager.shared.storeSemanticMemory(
                    category: .contextAssociation,
                    key: entity.type,
                    value: entity.value,
                    confidence: entity.confidence
                )
            }
        }
    }

    private func analyzeWithAI(_ event: LifeEvent) async {
        // Queue for AI analysis
        // This will be handled by the AI analysis pipeline
        logger.debug("Queuing event for AI analysis: \(event.type.rawValue)")
    }

    private func checkProactiveOpportunities(_ event: LifeEvent) async {
        // Check if this event should trigger proactive suggestions
        let context = MemoryContextSnapshot(
            userActivity: event.type.rawValue,
            currentQuery: event.summary,
            timeOfDay: Calendar.current.component(.hour, from: event.timestamp),
            dayOfWeek: Calendar.current.component(.weekday, from: event.timestamp)
        )

        // Check prospective memories
        let triggered = await MemoryManager.shared.checkProspectiveMemories(
            currentContext: context
        )

        for memory in triggered {
            logger.info("Memory trigger: \(memory.key)")
        }
    }

    private func publishToEventBus(_ event: LifeEvent) {
        EventBus.shared.publish(ComponentEvent(
            source: .system,
            action: "lifeEvent",
            component: "LifeMonitoringCoordinator",
            details: [
                "type": event.type.rawValue,
                "source": event.source.rawValue,
                "summary": event.summary
            ]
        ))
    }

    /// Queue event for iCloud sync
    private func queueForCloudSync(_ event: LifeEvent) {
        guard configuration.iCloudSyncEnabled else { return }

        // Convert to cloud-syncable format
        let eventData = try? JSONEncoder().encode(event.data)

        let cloudEvent = CloudLifeEvent(
            id: event.id,
            eventType: event.type.rawValue,
            sourceType: event.source.rawValue,
            timestamp: event.timestamp,
            data: eventData ?? Data()
        )

        cloudSync?.queueEvent(cloudEvent)
    }

    // MARK: - Cloud Sync

    private func startCloudSync() async {
        cloudSync = LifeMonitoringCloudSync.shared

        // Initial sync to get events from other devices
        if configuration.iCloudSyncEnabled {
            try? await cloudSync?.syncAll()
        }

        // Periodic sync every 5 minutes
        cloudSyncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
                guard !Task.isCancelled, configuration.iCloudSyncEnabled else { continue }
                try? await cloudSync?.syncAll()
            }
        }
    }

    private func setupCloudSyncObservers() {
        // Listen for events from other devices
        NotificationCenter.default.addObserver(
            forName: .lifeMonitoringRemoteEventReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?["event"] as? CloudLifeEvent else { return }
            Task { @MainActor in
                self?.handleRemoteEvent(event)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .lifeMonitoringRemoteReadingSession,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let session = notification.userInfo?["session"] as? CloudReadingSession else { return }
            Task { @MainActor in
                self?.handleRemoteReadingSession(session)
            }
        }
    }

    private func handleRemoteEvent(_ cloudEvent: CloudLifeEvent) {
        // Convert cloud event to local life event
        let event = LifeEvent(
            id: cloudEvent.id,
            timestamp: cloudEvent.timestamp,
            type: LifeEventType(rawValue: cloudEvent.eventType) ?? .pageVisit,
            source: DataSourceType(rawValue: cloudEvent.sourceType) ?? .browserExtension,
            summary: "Event from \(cloudEvent.sourceDeviceName)",
            data: ["fromDevice": cloudEvent.sourceDeviceName],
            significance: .minor
        )

        // Store in memory but don't re-sync
        Task {
            await storeInMemory(event)
        }

        logger.info("Received remote event from \(cloudEvent.sourceDeviceName)")
    }

    private func handleRemoteReadingSession(_ session: CloudReadingSession) {
        // Store reading session from another device
        logger.info("Received remote reading session from \(session.sourceDeviceName): \(session.title)")

        // Store as episodic memory
        Task {
            await MemoryManager.shared.storeEpisodicMemory(
                event: "page_read_remote",
                context: "\(session.title) on \(session.domain) (from \(session.sourceDeviceName))",
                outcome: "Read for \(session.activeTimeMs / 1000) seconds, \(session.maxScrollDepth)% scrolled",
                emotionalValence: 0.0
            )
        }
    }

    // MARK: - TV Activity (Tizen)

    /// Handle TV activity event from Samsung TV (via Cloudflare sync bridge)
    public func handleTVActivity(_ activity: TVActivityEvent) {
        guard configuration.tvActivityEnabled else { return }

        let event = LifeEvent(
            id: activity.id,
            timestamp: activity.timestamp,
            type: activity.toLifeEventType(),
            source: .tvActivity,
            summary: activity.description,
            data: activity.metadata,
            significance: activity.significance
        )

        submitEvent(event)
        activeDataSources.insert(.tvActivity)

        logger.info("TV activity: \(activity.description)")
    }

    // MARK: - Manual Event Submission

    /// Submit a life event manually (e.g., from integrations)
    public func submitEvent(_ event: LifeEvent) {
        eventSubject.send(event)
    }

    // MARK: - Configuration

    /// Update monitoring configuration
    public func updateConfiguration(_ config: LifeMonitoringConfiguration) async {
        let wasEnabled = isMonitoringEnabled

        configuration = config
        isMonitoringEnabled = config.enabled

        // Restart if configuration changed significantly
        if wasEnabled != isMonitoringEnabled {
            if isMonitoringEnabled {
                await startMonitoring()
            } else {
                await stopMonitoring()
            }
        }
    }

    // MARK: - Statistics

    /// Get monitoring statistics
    public func getStatistics() -> LifeMonitoringStatistics {
        LifeMonitoringStatistics(
            isEnabled: isMonitoringEnabled,
            activeSources: activeDataSources,
            todayEventCount: todayEventCount,
            lastEventTime: lastEventTime,
            connectionStatus: connectionStatus
        )
    }
}

// MARK: - WebSocket Server Delegate

extension LifeMonitoringCoordinator: LifeMonitorWebSocketServerDelegate {
    nonisolated public func webSocketServer(
        _ _server: LifeMonitorWebSocketServer,
        didReceiveData data: Data,
        from _clientId: String
    ) {
        Task { @MainActor in
            do {
                let browserEvent = try JSONDecoder().decode(BrowserEventPayload.self, from: data)
                let event = browserEvent.toLifeEvent()
                submitEvent(event)
            } catch {
                logger.error("Failed to decode browser event: \(error.localizedDescription)")
            }
        }
    }

    nonisolated public func webSocketServer(
        _ _server: LifeMonitorWebSocketServer,
        clientConnected clientId: String
    ) {
        Task { @MainActor in
            logger.info("Browser extension connected: \(clientId)")
            activeDataSources.insert(.browserExtension)
        }
    }

    nonisolated public func webSocketServer(
        _ _server: LifeMonitorWebSocketServer,
        clientDisconnected clientId: String
    ) {
        Task { @MainActor in
            logger.info("Browser extension disconnected: \(clientId)")
        }
    }
}

// MARK: - Monitor Delegates

#if os(macOS)
extension LifeMonitoringCoordinator: ClipboardMonitorDelegate {
    nonisolated public func clipboardMonitor(_ _monitor: ClipboardMonitor, didCapture content: MonitoredClipboardContent) {
        Task { @MainActor in
            let event = LifeEvent(
                type: .clipboardCopy,
                source: .clipboard,
                summary: content.preview,
                data: ["contentType": content.type.rawValue],
                significance: .minor
            )
            submitEvent(event)
        }
    }
}

extension LifeMonitoringCoordinator: MessagesMonitorDelegate {
    nonisolated public func messagesMonitor(_ _monitor: MessagesMonitor, didReceive message: MonitoredMessageEvent) {
        Task { @MainActor in
            let event = LifeEvent(
                type: message.isFromMe ? .messageSent : .messageReceived,
                source: .messages,
                summary: "Message with \(message.contactName ?? "Unknown")",
                data: [
                    "contactId": message.handleId,
                    "isFromMe": String(message.isFromMe),
                    "hasAttachment": String(message.hasAttachment)
                ],
                significance: .moderate,
                sentiment: message.sentiment
            )
            submitEvent(event)
        }
    }
}

extension LifeMonitoringCoordinator: MailMonitorDelegate {
    nonisolated public func mailMonitor(_ _monitor: MailMonitor, didReceive email: MailEvent) {
        Task { @MainActor in
            let event = LifeEvent(
                type: .emailReceived,
                source: .mail,
                summary: "Email from \(email.sender): \(email.subject)",
                data: [
                    "sender": email.sender,
                    "subject": email.subject,
                    "isRead": String(email.isRead)
                ],
                significance: email.isImportant ? .significant : .moderate
            )
            submitEvent(event)
        }
    }
}

extension LifeMonitoringCoordinator: FileSystemMonitorDelegate {
    nonisolated public func fileSystemMonitor(_ _monitor: FileSystemMonitor, didDetect change: FileSystemChange) {
        Task { @MainActor in
            let event = LifeEvent(
                type: .fileActivity,
                source: .fileSystem,
                summary: "\(change.type.rawValue): \(change.fileName)",
                data: [
                    "path": change.path,
                    "changeType": change.type.rawValue,
                    "fileType": change.fileType ?? "unknown"
                ],
                significance: .minor
            )
            submitEvent(event)
        }
    }
}
#endif

