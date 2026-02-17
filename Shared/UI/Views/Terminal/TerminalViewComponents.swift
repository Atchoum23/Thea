#if os(macOS)
    import SwiftUI

    // MARK: - Terminal Output View (with ANSI colors)

    /// Renders terminal output text with ANSI color code support
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

    // MARK: - Windows List View

    extension TerminalView {
        var windowsListView: some View {
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
                            .accessibilityLabel("Open Terminal")
                            .accessibilityHint("Opens the Terminal application")
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

        func windowRow(_ window: WindowInfo) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "macwindow")
                        .accessibilityHidden(true)
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
                            .accessibilityHidden(true)
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
                    .accessibilityElement(children: .combine)

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
                    .accessibilityLabel("Read Content")
                    .accessibilityHint("Reads the terminal content from window \(window.index)")

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
                    .accessibilityLabel("Execute Here")
                    .accessibilityHint("Executes the current command in window \(window.index)")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Command Input & Actions

    extension TerminalView {
        var commandInputView: some View {
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
                    .accessibilityLabel("Command input")
                    .accessibilityHint("Type a terminal command and press Return to execute")

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
                .accessibilityLabel("Execute command")

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
                .accessibilityLabel("Execution mode")
                .accessibilityHint("Select how commands are executed")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }

        func executeCommand() {
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

        func executeQuickCommand(_ command: QuickCommand) {
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

    #Preview {
        TerminalView()
            .frame(width: 900, height: 600)
    }

#endif
