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

    // Group 2: Features
    case clipboard = "Clipboard"
    case voiceInput = "Voice & Input"
    case codeIntelligence = "Code Intelligence"
    case health = "Health"
    case finance = "Finance"
    case tasks = "Tasks"
    case notifications = "Notifications"

    // Group 3: System
    case permissions = "Permissions"
    case sync = "Sync"
    case privacy = "Privacy"

    // Group 4: Customization
    case theme = "Theme"
    case advanced = "Advanced"

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
        case .clipboard: "doc.on.clipboard"
        case .voiceInput: "mic.fill"
        case .codeIntelligence: "chevron.left.forwardslash.chevron.right"
        case .health: "heart.fill"
        case .finance: "chart.line.uptrend.xyaxis"
        case .tasks: "checklist"
        case .notifications: "bell.badge"
        case .permissions: "hand.raised.fill"
        case .sync: "icloud.fill"
        case .privacy: "lock.shield"
        case .theme: "paintpalette"
        case .advanced: "slider.horizontal.3"
        case .subscription: "creditcard"
        case .about: "info.circle"
        }
    }

    var group: Int {
        switch self {
        case .general, .aiModels: 0
        case .providers, .memory, .agent, .moltbook, .knowledge: 1
        case .clipboard, .voiceInput, .codeIntelligence, .health, .finance, .tasks, .notifications: 2
        case .permissions, .sync, .privacy: 3
        case .theme, .advanced: 4
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
        case .clipboard:
            TheaClipSettingsView()
        case .voiceInput:
            voiceInputSettings
        case .codeIntelligence:
            CodeIntelligenceConfigurationView()
        case .health:
            HealthDashboardView()
        case .finance:
            FinancialDashboardView()
        case .tasks:
            TasksAndLifeView()
        case .notifications:
            NotificationIntelligenceSettingsView()
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
        case .subscription:
            SubscriptionSettingsView()
        case .about:
            AboutView()
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
