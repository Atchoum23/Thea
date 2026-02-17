#if os(macOS)
    import SwiftUI

    /// Main Terminal integration view
    struct TerminalView: View {
        @StateObject var manager = TerminalIntegrationManager.shared
        @State var commandInput = ""
        @State var isExecuting = false
        @State var showingQuickCommands = false
        @State var selectedTab: TerminalTab = .output

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

    }

    // MARK: - Sidebar

    extension TerminalView {
        var sidebarView: some View {
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
                        .fill(manager.isConnected ? Color.theaSuccess : Color.theaError)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(manager.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Terminal \(manager.isConnected ? "connected" : "disconnected")")

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
                    .accessibilityLabel("Monitoring terminal activity")
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
                            .background(Color.theaError.opacity(0.1))
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
                            .accessibilityLabel("Succeeded")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel("Failed")
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

        }

    // Supporting views (TerminalOutputView, windowsListView, commandInputView, actions) are in TerminalViewComponents.swift

#endif
