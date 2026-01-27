#if os(macOS)
    import SwiftUI

    /// Main Terminal integration view
    struct TerminalView: View {
        @StateObject private var manager = TerminalIntegrationManager.shared
        @State private var commandInput = ""
        @State private var isExecuting = false
        @State private var showingHistory = false
        @State private var showingQuickCommands = false
        @State private var selectedTab: TerminalTab = .output

        enum TerminalTab: String, CaseIterable {
            case output = "Output"
            case history = "History"
            case windows = "Windows"
        }

        var body: some View {
            HSplitView {
                // Left sidebar
                sidebarView
                    .frame(minWidth: 200, maxWidth: 300)

                // Main content
                VStack(spacing: 0) {
                    // Tab bar
                    tabBar

                    Divider()

                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                        case .output:
                            outputView
                        case .history:
                            CommandHistoryView()
                        case .windows:
                            windowsListView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // Command input
                    commandInputView
                }
            }
            .frame(minWidth: 700, minHeight: 500)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        Task { await manager.refreshWindowList() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        Task {
                            try? await manager.openNewWindow()
                        }
                    } label: {
                        Label("New Window", systemImage: "plus.rectangle")
                    }

                    Toggle(isOn: $manager.isEnabled) {
                        Label("Enabled", systemImage: manager.isEnabled ? "terminal.fill" : "terminal")
                    }
                }
            }
            .onAppear {
                Task { await manager.refreshWindowList() }
            }
        }

        // MARK: - Sidebar

        private var sidebarView: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Connection status
                connectionStatusView

                Divider()

                // Quick commands
                quickCommandsView

                Divider()

                // Sessions
                sessionsView

                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }

        private var connectionStatusView: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(manager.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(manager.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                }

                if manager.isConnected {
                    Text("\(manager.terminalWindows.count) window(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if manager.isMonitoring {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Monitoring...")
                            .font(.caption)
                    }
                }
            }
        }

        private var quickCommandsView: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quick Commands")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingQuickCommands.toggle()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(manager.quickCommands.prefix(8)) { command in
                            Button {
                                executeQuickCommand(command)
                            } label: {
                                HStack {
                                    Image(systemName: command.icon)
                                        .frame(width: 20)
                                    Text(command.name)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(nsColor: .controlColor))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isExecuting)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }

        private var sessionsView: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sessions")
                        .font(.headline)
                    Spacer()
                    Button {
                        _ = manager.createSession(name: "Session \(manager.sessions.count + 1)")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(manager.sessions) { session in
                            HStack {
                                Image(systemName: session.id == manager.currentSession?.id ? "terminal.fill" : "terminal")
                                Text(session.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(session.commandHistory.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(session.id == manager.currentSession?.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                            .onTapGesture {
                                manager.switchToSession(session)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }

        // MARK: - Tab Bar

        private var tabBar: some View {
            HStack(spacing: 0) {
                ForEach(TerminalTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }

        // MARK: - Output View

        private var outputView: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if let session = manager.currentSession {
                            ForEach(session.commandHistory) { command in
                                commandOutputRow(command)
                                    .id(command.id)
                            }
                        }

                        // Current output
                        if !manager.lastOutput.isEmpty {
                            Text("Latest Output:")
                                .font(.headline)
                                .padding(.top)

                            TerminalOutputView(text: manager.lastOutput)
                        }

                        // Error display
                        if !manager.lastError.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(manager.lastError)
                                    .foregroundStyle(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: manager.currentSession?.commandHistory.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }

        private func commandOutputRow(_ command: TerminalCommand) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                // Command line
                HStack {
                    Text("$")
                        .foregroundStyle(.green)
                        .fontWeight(.bold)
                    Text(command.command)
                        .fontDesign(.monospaced)
                    Spacer()
                    Text(command.executedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if command.wasSuccessful {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                // Output
                if !command.output.isEmpty {
                    TerminalOutputView(text: command.output)
                        .padding(.leading, 16)
                }

                // Error output
                if !command.errorOutput.isEmpty {
                    Text(command.errorOutput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.leading, 16)
                }

                // Duration
                Text("Duration: \(String(format: "%.2fs", command.duration))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()
            }
        }

        // MARK: - Windows List

        private var windowsListView: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if manager.terminalWindows.isEmpty {
                        ContentUnavailableView {
                            Label("No Terminal Windows", systemImage: "terminal")
                        } description: {
                            Text("Open Terminal.app to see windows here")
                        } actions: {
                            Button("Open Terminal") {
                                Task {
                                    try? await manager.openNewWindow()
                                }
                            }
                        }
                    } else {
                        ForEach(manager.terminalWindows) { window in
                            windowRow(window)
                        }
                    }
                }
                .padding()
            }
        }

        private func windowRow(_ window: WindowInfo) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Window \(window.index)")
                        .font(.headline)
                    Spacer()
                    Text("\(window.tabCount) tab(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(window.tabs) { tab in
                    HStack {
                        Image(systemName: tab.isBusy ? "play.fill" : "terminal")
                            .foregroundStyle(tab.isBusy ? .green : .secondary)
                        Text("Tab \(tab.index)")
                        if tab.isBusy {
                            Text("(busy)")
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(tab.tty)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 20)

                    if !tab.processes.isEmpty {
                        Text("Processes: \(tab.processes.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 40)
                    }
                }

                HStack {
                    Button("Read Content") {
                        Task {
                            if let content = try? await manager.readTerminalContent(windowIndex: window.index, tabIndex: window.selectedTab) {
                                manager.lastOutput = content
                                selectedTab = .output
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Execute Here") {
                        if !commandInput.isEmpty {
                            Task {
                                try? await manager.executeInTerminalTab(commandInput, windowIndex: window.index, tabIndex: window.selectedTab)
                                commandInput = ""
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(commandInput.isEmpty)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }

        // MARK: - Command Input

        private var commandInputView: some View {
            HStack(spacing: 12) {
                // Working directory
                if let session = manager.currentSession {
                    Text(session.workingDirectory.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("$")
                    .foregroundStyle(.green)
                    .fontWeight(.bold)

                TextField("Enter command...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        executeCommand()
                    }
                    .disabled(isExecuting || !manager.isEnabled)

                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button {
                    executeCommand()
                } label: {
                    Image(systemName: "return")
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandInput.isEmpty || isExecuting || !manager.isEnabled)

                Menu {
                    ForEach(TerminalIntegrationManager.ExecutionMode.allCases, id: \.self) { mode in
                        Button {
                            manager.executionMode = mode
                            manager.saveConfiguration()
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                if manager.executionMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }

        // MARK: - Actions

        private func executeCommand() {
            guard !commandInput.isEmpty else { return }

            let command = commandInput
            commandInput = ""
            isExecuting = true

            Task {
                do {
                    _ = try await manager.execute(command)
                } catch {
                    manager.lastError = error.localizedDescription
                }
                isExecuting = false
            }
        }

        private func executeQuickCommand(_ command: QuickCommand) {
            isExecuting = true

            Task {
                do {
                    _ = try await manager.executeQuickCommand(command)
                } catch {
                    manager.lastError = error.localizedDescription
                }
                isExecuting = false
            }
        }
    }

    // MARK: - Terminal Output View (with ANSI colors)

    struct TerminalOutputView: View {
        let text: String

        var body: some View {
            let segments = TerminalOutputParser.parseANSI(text)

            Text(segments.reduce(AttributedString()) { result, segment in
                var attributed = AttributedString(segment.text)

                if let fg = segment.style.foregroundColor {
                    attributed.foregroundColor = fg
                }
                if segment.style.isBold {
                    attributed.font = .system(.body, design: .monospaced).bold()
                } else {
                    attributed.font = .system(.body, design: .monospaced)
                }
                if segment.style.isUnderline {
                    attributed.underlineStyle = .single
                }

                return result + attributed
            })
            .textSelection(.enabled)
        }
    }

    #Preview {
        TerminalView()
            .frame(width: 900, height: 600)
    }

#endif
