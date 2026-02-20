// ToolUseStepView.swift
// Thea
//
// B3: Shows tool use steps inline in the chat — tool name, input summary, result.
// Used in MessageBubble to display AI tool execution transparently.

import SwiftUI

// MARK: - Single Tool Step View

struct ToolUseStepView: View {
    let step: ToolUseStep

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: toolIcon(for: step.toolName))
                .foregroundStyle(step.isRunning ? Color.accentColor : stepColor)
                .frame(width: 16, height: 16)
                .symbolEffect(.pulse, isActive: step.isRunning)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(toolDisplayName(for: step.toolName))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)

                    if step.isRunning {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else if step.errorMessage != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption2)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                    }
                }

                Text(step.inputSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let result = step.result, !result.isEmpty, !step.isRunning {
                    Text(result)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(4)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                }

                if let error = step.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var stepColor: Color {
        if step.errorMessage != nil { return .orange }
        return step.isRunning ? .accentColor : .secondary
    }

    private func toolIcon(for toolName: String) -> String {
        if toolName.hasPrefix("search_memory") || toolName.hasPrefix("list_memor") ||
           toolName.hasPrefix("add_memor") || toolName.hasPrefix("update_memor") ||
           toolName.hasPrefix("search_knowledge") { return "brain" }
        if toolName.hasPrefix("read_file") || toolName.hasPrefix("write_file") ||
           toolName.hasPrefix("list_directory") || toolName.hasPrefix("search_files") { return "doc.text" }
        if toolName.hasPrefix("web_search") || toolName.hasPrefix("fetch_url") { return "magnifyingglass" }
        if toolName.hasPrefix("run_code") || toolName.hasPrefix("analyze_code") { return "chevron.left.forwardslash.chevron.right" }
        if toolName.hasPrefix("calendar") { return "calendar" }
        if toolName.hasPrefix("reminder") { return "checkmark.circle" }
        if toolName.hasPrefix("mail") { return "envelope" }
        if toolName.hasPrefix("finder") { return "folder" }
        if toolName.hasPrefix("terminal") || toolName.hasPrefix("run_command") { return "terminal" }
        if toolName.hasPrefix("safari") { return "safari" }
        if toolName.hasPrefix("music") { return "music.note" }
        if toolName.hasPrefix("shortcuts") { return "bolt" }
        if toolName.hasPrefix("notes") { return "note.text" }
        if toolName.hasPrefix("system") { return "gear" }
        return "wrench.and.screwdriver"
    }

    private func toolDisplayName(for toolName: String) -> String {
        toolName
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Tool Steps Container (shown above message text)

struct ToolUseStepsView: View {
    let steps: [ToolUseStep]
    @State private var isExpanded = false

    var body: some View {
        if steps.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(steps.count) tool\(steps.count == 1 ? "" : "s") used")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    ForEach(steps) { step in
                        ToolUseStepView(step: step)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Tool Steps") {
    VStack(spacing: 8) {
        ToolUseStepView(step: ToolUseStep(call: AnthropicToolCall(
            id: "1", name: "search_memory", input: ["query": "Swift concurrency", "_tool_use_id": "1"]
        )))
        ToolUseStepView(step: {
            var s = ToolUseStep(call: AnthropicToolCall(
                id: "2", name: "web_search", input: ["query": "WWDC 2026", "_tool_use_id": "2"]
            ))
            s.isRunning = false
            s.result = "Found 5 relevant results about WWDC 2026 announcements"
            return s
        }())
        ToolUseStepsView(steps: [
            ToolUseStep(call: AnthropicToolCall(
                id: "3", name: "read_file", input: ["path": "~/Documents/notes.txt", "_tool_use_id": "3"]
            ))
        ])
    }
    .padding()
}
