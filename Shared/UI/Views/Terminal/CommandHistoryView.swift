#if os(macOS)
    import SwiftUI

    /// View for browsing and searching command history
    struct CommandHistoryView: View {
        @StateObject private var manager = TerminalIntegrationManager.shared
        @State private var searchText = ""
        @State private var selectedFilter: HistoryFilter = .all
        @State private var sortOrder: SortOrder = .newest

        enum HistoryFilter: String, CaseIterable {
            case all = "All"
            case successful = "Successful"
            case failed = "Failed"
            case favorites = "Favorites"
        }

        enum SortOrder: String, CaseIterable {
            case newest = "Newest First"
            case oldest = "Oldest First"
            case mostUsed = "Most Used"
        }

        private var filteredHistory: [TerminalCommand] {
            guard let session = manager.currentSession else { return [] }

            var commands = session.commandHistory

            // Apply search filter
            if !searchText.isEmpty {
                commands = commands.filter {
                    $0.command.localizedCaseInsensitiveContains(searchText) ||
                        $0.output.localizedCaseInsensitiveContains(searchText)
                }
            }

            // Apply status filter
            switch selectedFilter {
            case .all:
                break
            case .successful:
                commands = commands.filter(\.wasSuccessful)
            case .failed:
                commands = commands.filter { !$0.wasSuccessful }
            case .favorites:
                let favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "terminal.favoriteCommands") ?? [])
                commands = commands.filter { favoriteIDs.contains($0.id.uuidString) }
            }

            // Apply sort
            switch sortOrder {
            case .newest:
                commands = commands.sorted { $0.executedAt > $1.executedAt }
            case .oldest:
                commands = commands.sorted { $0.executedAt < $1.executedAt }
            case .mostUsed:
                // Group by command and sort by frequency
                let grouped = Dictionary(grouping: commands) { $0.command }
                let sorted = grouped.sorted { $0.value.count > $1.value.count }
                commands = sorted.flatMap(\.value)
            }

            return commands
        }

        var body: some View {
            VStack(spacing: 0) {
                // Search and filters
                filterBar

                Divider()

                // History list
                if filteredHistory.isEmpty {
                    ContentUnavailableView {
                        Label("No Commands", systemImage: "terminal")
                    } description: {
                        if searchText.isEmpty {
                            Text("Execute some commands to see them here")
                        } else {
                            Text("No commands match '\(searchText)'")
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredHistory) { command in
                                CommandHistoryRow(command: command) {
                                    rerunCommand(command)
                                }
                            }
                        }
                        .padding()
                    }
                }

                Divider()

                // Statistics
                statisticsBar
            }
        }

        private var filterBar: some View {
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.controlBackground)
                .cornerRadius(8)

                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                // Sort picker
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 150)

                Button {
                    clearHistory()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }

        private var statisticsBar: some View {
            HStack(spacing: 20) {
                if let session = manager.currentSession {
                    Label("\(session.commandHistory.count) commands", systemImage: "number")

                    let successful = session.commandHistory.count { $0.wasSuccessful }
                    Label("\(successful) successful", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)

                    let failed = session.commandHistory.count { !$0.wasSuccessful }
                    Label("\(failed) failed", systemImage: "xmark.circle")
                        .foregroundStyle(.red)

                    let totalDuration = session.commandHistory.reduce(0) { $0 + $1.duration }
                    Label(String(format: "%.1fs total", totalDuration), systemImage: "clock")
                }

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .background(Color.controlBackground)
        }

        private func rerunCommand(_ command: TerminalCommand) {
            Task {
                do {
                    _ = try await manager.execute(command.command)
                } catch {
                    manager.lastError = error.localizedDescription
                }
            }
        }

        private func clearHistory() {
            manager.currentSession?.commandHistory.removeAll()
        }
    }

    // MARK: - Command History Row

    struct CommandHistoryRow: View {
        let command: TerminalCommand
        let onRerun: () -> Void

        @State private var isExpanded = false
        @State private var isCopied = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    // Status indicator
                    Image(systemName: command.wasSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(command.wasSuccessful ? .green : .red)

                    // Command text
                    Text(command.command)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(isExpanded ? nil : 1)

                    Spacer()

                    // Time and duration
                    VStack(alignment: .trailing) {
                        Text(command.executedAt, style: .time)
                            .font(.caption)
                        Text(String(format: "%.2fs", command.duration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button {
                            copyToClipboard(command.command)
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy command")

                        Button {
                            onRerun()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.plain)
                        .help("Run again")

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isExpanded ? "Collapse command output" : "Expand command output")
                    }
                }

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        if !command.output.isEmpty {
                            GroupBox("Output") {
                                ScrollView {
                                    Text(command.output)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 200)
                            }
                        }

                        if !command.errorOutput.isEmpty {
                            GroupBox("Error Output") {
                                ScrollView {
                                    Text(command.errorOutput)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.red)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 100)
                            }
                        }

                        HStack {
                            Label("Exit Code: \(command.exitCode)", systemImage: "number.circle")
                            Spacer()
                            Label(command.workingDirectory.path, systemImage: "folder")
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }
            .padding()
            .background(Color.controlBackground)
            .cornerRadius(8)
        }

        private func copyToClipboard(_ text: String) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isCopied = false
            }
        }
    }

    #Preview {
        CommandHistoryView()
            .frame(width: 800, height: 600)
    }

#endif
