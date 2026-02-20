@preconcurrency import SwiftData
import SwiftUI

// MARK: - Window Resizable Helper

/// Invisible NSView that forces its host NSWindow to accept the `.resizable` style mask
/// and persists its frame (position + size) across relaunches.
/// SwiftUI's `Settings` scene actively strips `.resizable` -- we use KVO to re-inject
/// it every time the system removes it, ensuring the resize handle always appears.
private struct WindowResizableHelper: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ResizableInjectorView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private class ResizableInjectorView: NSView {
        private var observation: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else {
                observation = nil
                return
            }
            window.styleMask.insert(.resizable)

            window.setFrameAutosaveName("TheaSettingsWindow")

            observation = window.observe(\.styleMask, options: [.new]) { win, _ in
                DispatchQueue.main.async { @MainActor in
                    if !win.styleMask.contains(.resizable) {
                        win.styleMask.insert(.resizable)
                    }
                }
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

// MARK: - Settings Category

/// Sidebar categories modeled after macOS System Settings.
enum SettingsCategory: String, CaseIterable, Identifiable {
    // Group 0: Core
    case general = "General"
    case aiModels = "AI & Models"

    // Group 1: Intelligence
    case providers = "Providers"
    case memory = "Memory"
    case agent = "Agent"
    case moltbook = "Moltbook"
    case knowledge = "Knowledge"
    case knowledgeGraph = "Knowledge Graph"
    case liveGuidance = "Live Guidance"
    case metaAI = "Meta-AI"
    case squads = "Squads"
    case intelligenceDashboard = "Intelligence Dashboard"
    case skills = "Skills"
    case behavioralPatterns = "Behavioral Patterns"
    case notificationSchedule = "Notification Schedule"
    case conversationSettings = "Conversation"
    case personalization = "Personalization"
    case responseStyles = "Response Styles"
    case aiFeatures = "AI Features"
    case workflowSettings = "Workflows"

    // Group 2: Features
    case clipboard = "Clipboard"
    case translation = "Translation"
    case voiceInput = "Voice & Input"
    case codeIntelligence = "Code Intelligence"
    case imageIntelligence = "Image Intelligence"
    case health = "Health"
    case lifeTracking = "Life Tracking"
    case finance = "Finance"
    case tasks = "Tasks"
    case habits = "Habits"
    case packages = "Packages"
    case documents = "Documents"
    case documentSuite = "Document Suite"
    case downloads = "Downloads"
    case webClipper = "Web Clipper"
    case qrScanner = "QR Scanner"
    case mediaPlayer = "Media Player"
    case mediaServer = "Media Server"
    case notifications = "Notifications"
    case messaging = "Messaging Hub"
    case messagingGateway = "Messaging Gateway"
    case messagingChat = "Messaging Chat"
    case travel = "Travel"
    case vehicles = "Vehicles"
    case extSubscriptions = "Subscriptions"
    case passwords = "Passwords"
    case learning = "Learning"
    case home = "Home"
    case appPairing = "App Pairing"
    case shortcuts = "Shortcuts"
    case wakeWord = "Wake Word"
    case promptEngineering = "Prompt Engineering"
    case systemPrompt = "System Prompt"
    case remoteAccess = "Remote Access"
    case healthInsights = "Health Insights"

    // Group 3: System & Analytics
    case behavioralAnalytics = "Behavioral Analytics"
    case privacyTransparency = "Privacy Transparency"
    case gatewayStatus = "Gateway Status"
    case notificationIntel = "Notification Intel"
    case systemMonitor = "System Monitor"
    case systemCleaner = "System Cleaner"
    case battery = "Battery"
    case serviceHealth = "Service Health"
    case securityScanner = "Security"
    case permissions = "Permissions"
    case sync = "Sync"
    case privacy = "Privacy"
    case monitoringSettings = "Monitoring"

    // Group 4: Customization
    case theme = "Theme"
    case advanced = "Advanced"
    case mcpBuilder = "MCP Builder"

    // Group 5: Account & Info
    case subscription = "Subscription"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gear"
        case .aiModels: "brain.head.profile"
        case .providers: "server.rack"
        case .memory: "memorychip"
        case .agent: "person.2.circle"
        case .moltbook: "bubble.left.and.text.bubble.right"
        case .knowledge: "books.vertical"
        case .knowledgeGraph: "dot.radiowaves.forward"
        case .liveGuidance: "eye.circle.fill"
        case .metaAI: "brain.filled.head.profile"
        case .squads: "person.3.sequence.fill"
        case .intelligenceDashboard: "chart.bar.xaxis"
        case .skills: "bolt.badge.clock"
        case .behavioralPatterns: "waveform.path.ecg"
        case .notificationSchedule: "clock.badge.checkmark"
        case .conversationSettings: "bubble.left.and.bubble.right"
        case .personalization: "person.crop.circle.badge.plus"
        case .responseStyles: "text.alignleft"
        case .aiFeatures: "sparkles.rectangle.stack"
        case .workflowSettings: "arrow.triangle.branch"
        case .clipboard: "doc.on.clipboard"
        case .translation: "character.bubble"
        case .voiceInput: "mic.fill"
        case .codeIntelligence: "chevron.left.forwardslash.chevron.right"
        case .imageIntelligence: "photo.artframe"
        case .health: "heart.fill"
        case .lifeTracking: "figure.walk.motion"
        case .finance: "chart.line.uptrend.xyaxis"
        case .tasks: "checklist"
        case .habits: "repeat.circle"
        case .packages: "shippingbox"
        case .documents: "doc.viewfinder"
        case .documentSuite: "doc.richtext"
        case .downloads: "arrow.down.circle"
        case .webClipper: "scissors"
        case .qrScanner: "qrcode"
        case .mediaPlayer: "play.rectangle"
        case .mediaServer: "network"
        case .notifications: "bell.badge"
        case .messaging: "bubble.left.and.text.bubble.right.fill"
        case .messagingGateway: "antenna.radiowaves.left.and.right"
        case .messagingChat: "message.fill"
        case .travel: "airplane"
        case .vehicles: "car"
        case .extSubscriptions: "creditcard.circle"
        case .passwords: "lock.shield"
        case .learning: "graduationcap"
        case .home: "house.fill"
        case .appPairing: "link.circle"
        case .shortcuts: "keyboard"
        case .wakeWord: "waveform.badge.mic"
        case .promptEngineering: "text.badge.star"
        case .systemPrompt: "doc.badge.gearshape"
        case .remoteAccess: "wifi.circle"
        case .healthInsights: "heart.text.square"
        case .behavioralAnalytics: "chart.bar.xaxis"
        case .privacyTransparency: "eye.slash.fill"
        case .gatewayStatus: "antenna.radiowaves.left.and.right"
        case .notificationIntel: "bell.badge.fill"
        case .systemMonitor: "gauge.with.dots.needle.33percent"
        case .systemCleaner: "trash.circle"
        case .battery: "battery.75"
        case .serviceHealth: "stethoscope"
        case .securityScanner: "shield.lefthalf.filled"
        case .permissions: "hand.raised.fill"
        case .sync: "icloud.fill"
        case .privacy: "lock.shield"
        case .monitoringSettings: "waveform.and.magnifyingglass"
        case .theme: "paintpalette"
        case .advanced: "slider.horizontal.3"
        case .mcpBuilder: "network.badge.shield.half.filled"
        case .subscription: "creditcard"
        case .about: "info.circle"
        }
    }

    var group: Int {
        switch self {
        case .general, .aiModels: 0
        case .providers, .memory, .agent, .moltbook, .knowledge, .knowledgeGraph, .liveGuidance, .metaAI, .squads, .intelligenceDashboard, .skills, .behavioralPatterns, .notificationSchedule, .conversationSettings, .personalization, .responseStyles, .aiFeatures, .workflowSettings: 1
        case .clipboard, .translation, .voiceInput, .codeIntelligence, .imageIntelligence, .health, .lifeTracking, .finance, .tasks, .habits, .packages, .documents, .documentSuite, .downloads, .webClipper, .qrScanner, .mediaPlayer, .mediaServer, .notifications, .messaging, .messagingGateway, .messagingChat, .travel, .vehicles, .extSubscriptions, .passwords, .learning, .home, .appPairing, .shortcuts, .wakeWord, .promptEngineering, .systemPrompt, .remoteAccess, .healthInsights: 2
        case .behavioralAnalytics, .privacyTransparency, .gatewayStatus, .notificationIntel,
             .systemMonitor, .systemCleaner, .battery, .serviceHealth, .securityScanner, .permissions, .sync, .privacy, .monitoringSettings: 3
        case .theme, .advanced, .mcpBuilder: 4
        case .subscription, .about: 5
        }
    }

    /// Categories grouped for sidebar display with dividers between groups.
    static var grouped: [[SettingsCategory]] {
        let groups = Dictionary(grouping: allCases, by: \.group)
        return groups.keys.sorted().compactMap { groups[$0] }
    }
}

// MARK: - macOS Settings View

/// Consolidated macOS settings with a System Settings-style sidebar/detail layout.
struct MacSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @StateObject var settingsManager = SettingsManager.shared
    @State var voiceManager = VoiceActivationManager.shared

    // Sidebar state
    @State var selectedCategory: SettingsCategory? = .general
    @State var searchText: String = ""

    // AI & Models state
    @State var openAIKey: String = ""
    @State var anthropicKey: String = ""
    @State var googleKey: String = ""
    @State var perplexityKey: String = ""
    @State var groqKey: String = ""
    @State var openRouterKey: String = ""
    @State var apiKeysLoaded: Bool = false
    @State var localModelConfig = AppConfiguration.shared.localModelConfig
    @State var cacheSize: String = "Calculating..."

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            settingsSidebar
        } detail: {
            settingsDetail
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .toolbar(removing: .sidebarToggle)
        .frame(
            minWidth: 780, idealWidth: 920, maxWidth: .infinity,
            minHeight: 500, idealHeight: 640, maxHeight: .infinity
        )
        .background(WindowResizableHelper())
        .textSelection(.enabled)
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCategory) {
                ForEach(Array(filteredGroups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider()
                    }
                    ForEach(group) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")

            // Cloud sync status footer in sidebar
            Divider()
            HStack(spacing: TheaSpacing.sm) {
                CloudSyncStatusView(showLabel: true)
                Spacer()
            }
            .padding(.horizontal, TheaSpacing.md)
            .padding(.vertical, TheaSpacing.sm)
        }
    }

    private var filteredGroups: [[SettingsCategory]] {
        if searchText.isEmpty {
            return SettingsCategory.grouped
        }
        let query = searchText.lowercased()
        let filtered = SettingsCategory.allCases.filter {
            $0.rawValue.lowercased().contains(query)
        }
        return filtered.isEmpty ? [] : [filtered]
    }

    // MARK: - Detail View Router

    @ViewBuilder
    private var settingsDetail: some View {
        if let category = selectedCategory {
            detailContent(for: category)
                .id(category)
        } else {
            Text("Select a category")
                .font(.theaTitle3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    // swiftlint:disable:next function_body_length
    private func detailContent(for category: SettingsCategory) -> some View {
        switch category {
        case .general:
            generalSettings
        case .aiModels:
            aiSettings
        case .providers:
            providersSettings
        case .memory:
            MemoryConfigurationView()
        case .agent:
            AgentConfigurationView()
        case .moltbook:
            MoltbookSettingsView()
        case .knowledge:
            KnowledgeScannerConfigurationView()
        case .liveGuidance:
            LiveGuidanceSettingsView()
        case .metaAI:
            MetaAIDashboardView()
        case .squads:
            SquadsView()
        case .intelligenceDashboard:
            IntelligenceDashboardView()
        case .skills:
            SkillsMarketplaceView()
        case .clipboard:
            TheaClipSettingsView()
        case .translation:
            TranslationView()
        case .voiceInput:
            voiceInputSettings
        case .codeIntelligence:
            CodeAssistantView()
        case .health:
            HealthDashboardView()
        case .finance:
            FinancialDashboardView()
        case .tasks:
            TasksAndLifeView()
        case .habits:
            HabitTrackerView()
        case .packages:
            PackageTrackerView()
        case .documents:
            DocumentScannerView()
        case .documentSuite:
            DocumentSuiteView()
        case .downloads:
            DownloadManagerView()
        case .webClipper:
            WebClipperView()
        case .qrScanner:
            QRIntelligenceView()
        case .imageIntelligence:
            ImageIntelligenceView()
        case .mediaPlayer:
            MediaPlayerView()
        case .mediaServer:
            MediaServerView()
        case .notifications:
            NotificationIntelligenceSettingsView()
        case .messaging:
            MessagingHubView()
        case .messagingGateway:
            TheaMessagingSettingsView()
        case .travel:
            TravelPlanningView()
        case .vehicles:
            VehicleMaintenanceView()
        case .extSubscriptions:
            ExternalSubscriptionsView()
        case .passwords:
            PasswordVaultView()
        case .learning:
            LearningDashboardView()
        case .home:
            HomeIntelligenceView()
        case .behavioralAnalytics:
            BehavioralAnalyticsView()
        case .privacyTransparency:
            PrivacyTransparencyView()
        case .gatewayStatus:
            MessagingGatewayStatusView()
        case .notificationIntel:
            NotificationIntelligenceView()
        case .systemMonitor:
            SystemMonitorView()
        case .systemCleaner:
            SystemCleanerView()
        case .battery:
            BatteryIntelligenceView()
        case .serviceHealth:
            ServiceHealthDashboardView()
        case .securityScanner:
            SecurityScannerView()
        case .permissions:
            PermissionsSettingsView()
        case .sync:
            SyncSettingsView()
        case .privacy:
            ConfigurationPrivacySettingsView()
        case .theme:
            ThemeConfigurationView()
        case .advanced:
            advancedSettings
        case .mcpBuilder:
            MCPBuilderView()
        case .subscription:
            SubscriptionSettingsView()
        case .about:
            AboutView()
        case .knowledgeGraph:
            KnowledgeGraphExplorerView()
        case .behavioralPatterns:
            BehavioralPatternsView()
        case .notificationSchedule:
            NotificationScheduleView()
        case .conversationSettings:
            ConversationSettingsView()
        case .personalization:
            PersonalizationSettingsView()
        case .responseStyles:
            ResponseStylesSettingsView()
        case .lifeTracking:
            LifeTrackingSettingsView()
        case .messagingChat:
            TheaMessagingChatView()
        case .appPairing:
            AppPairingSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .wakeWord:
            WakeWordSettingsView()
        case .promptEngineering:
            PromptEngineeringSettingsView()
        case .systemPrompt:
            SystemPromptSettingsView()
        case .aiFeatures:
            AIFeaturesSettingsView()
        case .workflowSettings:
            WorkflowSettingsView()
        case .remoteAccess:
            RemoteAccessSettingsView()
        case .healthInsights:
            HealthInsightsView()
        case .monitoringSettings:
            MonitoringSettingsView()
        }
    }
}

// MARK: - Tasks & Life Management Composite View

/// Combined view for Tasks tab — shows task manager with life dashboard tabs.
private struct TasksAndLifeView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Tasks").tag(0)
                Text("Life Dashboard").tag(1)
                Text("Briefing").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().padding(.top, 8)

            switch selectedTab {
            case 0:
                TaskManagerView()
            case 2:
                MorningBriefingView()
            default:
                LifeManagementDashboardView()
            }
        }
        .navigationTitle(
            selectedTab == 0 ? "Tasks" : selectedTab == 2 ? "Morning Briefing" : "Life Dashboard"
        )
    }
}
