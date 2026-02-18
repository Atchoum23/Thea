#if os(macOS)
    import SwiftUI

    /// Settings view for Terminal.app integration
    struct TerminalSettingsView: View {
        @StateObject private var manager = TerminalIntegrationManager.shared
        @State private var newBlockedCommand = ""
        @State private var newConfirmCommand = ""
        @State private var showingDirectoryPicker = false
        @State private var selectedTerminalSecurityLevel: TerminalSecurityLevel = .standard

        var body: some View {
            Form {
                // General section
                generalSection

                // Execution section
                executionSection

                // Security section
                securitySection

                // Quick Commands section
                quickCommandsSection

                // Advanced section
                advancedSection

                // Reset section
                resetSection
            }
            .formStyle(.grouped)
            .navigationTitle("Terminal Integration")
            .onAppear {
                // Determine current security level
                if manager.securityPolicy == .unrestricted {
                    selectedTerminalSecurityLevel = .unrestricted
                } else if manager.securityPolicy == .sandboxed {
                    selectedTerminalSecurityLevel = .sandboxed
                } else {
                    selectedTerminalSecurityLevel = .standard
                }
            }
        }

        // MARK: - General Section

        private var generalSection: some View {
            Section {
                Toggle("Enable Terminal Integration", isOn: $manager.isEnabled)
                    .onChange(of: manager.isEnabled) { _, _ in
                        manager.saveConfiguration()
                    }

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(manager.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }
                }

                if manager.isConnected {
                    HStack {
                        Text("Terminal Windows")
                        Spacer()
                        Text("\(manager.terminalWindows.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("General")
            } footer: {
                Text("When enabled, Thea can read Terminal.app content and execute commands.")
            }
        }

        // MARK: - Execution Section

        private var executionSection: some View {
            Section {
                Picker("Execution Mode", selection: $manager.executionMode) {
                    ForEach(TerminalIntegrationManager.ExecutionMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .onChange(of: manager.executionMode) { _, _ in
                    manager.saveConfiguration()
                }

                Text(manager.executionMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Show Output In", selection: $manager.showOutputIn) {
                    ForEach(TerminalIntegrationManager.OutputDisplay.allCases, id: \.self) { display in
                        Text(display.rawValue).tag(display)
                    }
                }
                .onChange(of: manager.showOutputIn) { _, _ in
                    manager.saveConfiguration()
                }

                Toggle("Log All Commands", isOn: $manager.securityPolicy.logAllCommands)
                    .onChange(of: manager.securityPolicy.logAllCommands) { _, _ in
                        manager.saveConfiguration()
                    }

                Toggle("Redact Sensitive Output", isOn: $manager.securityPolicy.redactSensitiveOutput)
                    .onChange(of: manager.securityPolicy.redactSensitiveOutput) { _, _ in
                        manager.saveConfiguration()
                    }
                    .help("Automatically hide API keys, passwords, and tokens in command output")
            } header: {
                Text("Execution")
            }
        }

        // MARK: - Security Section

        private var securitySection: some View {
            Section {
                Picker("Security Level", selection: $selectedTerminalSecurityLevel) {
                    ForEach(TerminalSecurityLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.rawValue)
                        }
                        .tag(level)
                    }
                }
                .onChange(of: selectedTerminalSecurityLevel) { _, newLevel in
                    manager.securityPolicy = newLevel.policy
                    manager.saveConfiguration()
                }

                Text(selectedTerminalSecurityLevel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Sudo toggle
                Toggle("Allow Sudo Commands", isOn: $manager.securityPolicy.allowSudo)
                    .onChange(of: manager.securityPolicy.allowSudo) { _, _ in
                        manager.saveConfiguration()
                    }

                if manager.securityPolicy.allowSudo {
                    Label("Sudo commands can perform privileged operations. Use with caution.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                // Network commands
                Toggle("Allow Network Commands", isOn: $manager.securityPolicy.allowNetworkCommands)
                    .onChange(of: manager.securityPolicy.allowNetworkCommands) { _, _ in
                        manager.saveConfiguration()
                    }
                    .help("curl, wget, ssh, etc.")

                // File modification
                Toggle("Allow File Modification", isOn: $manager.securityPolicy.allowFileModification)
                    .onChange(of: manager.securityPolicy.allowFileModification) { _, _ in
                        manager.saveConfiguration()
                    }

                // Max execution time
                VStack(alignment: .leading) {
                    Text("Max Execution Time: \(Int(manager.securityPolicy.maxExecutionTime))s")
                    Slider(
                        value: $manager.securityPolicy.maxExecutionTime,
                        in: 30 ... 1800,
                        step: 30
                    )
                    .onChange(of: manager.securityPolicy.maxExecutionTime) { _, _ in
                        manager.saveConfiguration()
                    }
                }

                // Blocked commands
                DisclosureGroup("Blocked Commands (\(manager.securityPolicy.blockedCommands.count))") {
                    ForEach(manager.securityPolicy.blockedCommands, id: \.self) { cmd in
                        HStack {
                            Text(cmd)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                manager.securityPolicy.blockedCommands.removeAll { $0 == cmd }
                                manager.saveConfiguration()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Add blocked command...", text: $newBlockedCommand)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            if !newBlockedCommand.isEmpty {
                                manager.securityPolicy.blockedCommands.append(newBlockedCommand)
                                newBlockedCommand = ""
                                manager.saveConfiguration()
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newBlockedCommand.isEmpty)
                    }
                }

                // Confirmation required commands
                DisclosureGroup("Require Confirmation (\(manager.securityPolicy.requireConfirmation.count))") {
                    ForEach(manager.securityPolicy.requireConfirmation, id: \.self) { cmd in
                        HStack {
                            Text(cmd)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                manager.securityPolicy.requireConfirmation.removeAll { $0 == cmd }
                                manager.saveConfiguration()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Add command requiring confirmation...", text: $newConfirmCommand)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            if !newConfirmCommand.isEmpty {
                                manager.securityPolicy.requireConfirmation.append(newConfirmCommand)
                                newConfirmCommand = ""
                                manager.saveConfiguration()
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newConfirmCommand.isEmpty)
                    }
                }

                // Sandboxed directories
                if selectedTerminalSecurityLevel == .sandboxed || !manager.securityPolicy.sandboxedDirectories.isEmpty {
                    DisclosureGroup("Sandboxed Directories (\(manager.securityPolicy.sandboxedDirectories.count))") {
                        ForEach(manager.securityPolicy.sandboxedDirectories, id: \.self) { dir in
                            HStack {
                                Image(systemName: "folder")
                                Text(dir.path)
                                    .lineLimit(1)
                                Spacer()
                                Button(role: .destructive) {
                                    manager.securityPolicy.sandboxedDirectories.removeAll { $0 == dir }
                                    manager.saveConfiguration()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            showingDirectoryPicker = true
                        } label: {
                            Label("Add Directory", systemImage: "plus")
                        }
                    }
                    .fileImporter(
                        isPresented: $showingDirectoryPicker,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        if case let .success(urls) = result, let url = urls.first {
                            manager.securityPolicy.sandboxedDirectories.append(url)
                            manager.saveConfiguration()
                        }
                    }
                }
            } header: {
                Text("Security")
            } footer: {
                Text("Security policies control what commands can be executed and what requires confirmation.")
            }
        }

        // MARK: - Quick Commands Section

        private var quickCommandsSection: some View {
            Section {
                ForEach(manager.quickCommands) { command in
                    HStack {
                        Image(systemName: command.icon)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(command.name)
                            Text(command.command)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(command.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.controlBackground)
                            .cornerRadius(4)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        manager.quickCommands.remove(at: index)
                    }
                    manager.saveConfiguration()
                }

                NavigationLink("Manage Quick Commands") {
                    QuickCommandsEditorView()
                }
            } header: {
                Text("Quick Commands")
            } footer: {
                Text("Pre-configured command templates for common tasks.")
            }
        }

        // MARK: - Advanced Section

        private var advancedSection: some View {
            Section {
                // Session shell
                if let session = manager.currentSession {
                    Picker("Default Shell", selection: Binding(
                        get: { session.shellType },
                        set: { newValue in
                            session.shellType = newValue
                        }
                    )) {
                        ForEach(TerminalSession.ShellType.allCases, id: \.self) { shell in
                            Text(shell.displayName).tag(shell)
                        }
                    }
                }

                // Accessibility status
                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    if AccessibilityBridge.isAccessibilityEnabled() {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Request Access") {
                            AccessibilityBridge.requestAccessibilityAccess()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Text("Accessibility access enables advanced Terminal reading features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Advanced")
            }
        }

        // MARK: - Reset Section

        private var resetSection: some View {
            Section {
                Button("Reset Quick Commands to Defaults") {
                    manager.quickCommands = QuickCommand.defaults
                    manager.saveConfiguration()
                }

                Button("Reset Security Policy to Standard") {
                    manager.securityPolicy = .default
                    selectedTerminalSecurityLevel = .standard
                    manager.saveConfiguration()
                }

                Button("Clear Command History", role: .destructive) {
                    manager.currentSession?.commandHistory.removeAll()
                }
            } header: {
                Text("Reset")
            }
        }
    }

    // QuickCommandsEditorView and Preview are in TerminalSettingsViewSections.swift
#endif
