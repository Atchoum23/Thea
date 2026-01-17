#if os(macOS)
import SwiftUI

/// Detailed progress view showing step-by-step execution
struct CoworkProgressView: View {
    @State private var manager = CoworkManager.shared
    @State private var expandedSteps: Set<UUID> = []

    var body: some View {
        if let session = manager.currentSession, !session.steps.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Session header
                    sessionHeader(session)

                    Divider()

                    // Steps
                    ForEach(session.steps) { step in
                        stepCard(step)
                    }

                    // Session summary (if completed)
                    if session.status == .completed {
                        summaryCard(session)
                    }
                }
                .padding()
            }
        } else {
            emptyStateView
        }
    }

    // MARK: - Session Header

    private func sessionHeader(_ session: CoworkSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.name)
                    .font(.title2.bold())

                Spacer()

                StatusBadge(status: session.status)
            }

            if !session.context.userInstructions.isEmpty {
                Text(session.context.userInstructions)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: session.progress)
                    .progressViewStyle(.linear)

                HStack {
                    Text("\(session.completedSteps.count) of \(session.steps.count) steps completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let eta = session.estimatedTimeRemaining {
                        Text("~\(formatDuration(eta)) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Step Card

    private func stepCard(_ step: CoworkStep) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step header
            Button {
                withAnimation {
                    if expandedSteps.contains(step.id) {
                        expandedSteps.remove(step.id)
                    } else {
                        expandedSteps.insert(step.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(colorForStepStatus(step.status).opacity(0.2))
                            .frame(width: 32, height: 32)

                        if step.status == .inProgress {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: step.status.icon)
                                .foregroundStyle(colorForStepStatus(step.status))
                        }
                    }

                    // Step info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Step \(step.stepNumber)")
                                .font(.headline)
                            Text(step.status.rawValue)
                                .font(.caption)
                                .foregroundStyle(colorForStepStatus(step.status))
                        }

                        Text(step.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(expandedSteps.contains(step.id) ? nil : 1)
                    }

                    Spacer()

                    // Duration
                    if let duration = step.duration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Expand indicator
                    Image(systemName: expandedSteps.contains(step.id) ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if expandedSteps.contains(step.id) {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // Tools used
                    if !step.toolsUsed.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tools Used")
                                .font(.caption.bold())
                            FlowLayout(spacing: 4) {
                                ForEach(step.toolsUsed, id: \.self) { tool in
                                    Text(tool)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Input files
                    if !step.inputFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input Files (\(step.inputFiles.count))")
                                .font(.caption.bold())
                            ForEach(step.inputFiles.prefix(5), id: \.self) { file in
                                HStack {
                                    Image(systemName: "doc")
                                    Text(file.lastPathComponent)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            if step.inputFiles.count > 5 {
                                Text("... and \(step.inputFiles.count - 5) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Output files
                    if !step.outputFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output Files (\(step.outputFiles.count))")
                                .font(.caption.bold())
                            ForEach(step.outputFiles.prefix(5), id: \.self) { file in
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text(file.lastPathComponent)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundStyle(.green)
                            }
                        }
                    }

                    // Error
                    if let error = step.error {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Logs
                    if !step.logs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Logs")
                                .font(.caption.bold())
                            ForEach(step.logs.suffix(5)) { log in
                                HStack(spacing: 4) {
                                    Image(systemName: log.level.icon)
                                        .foregroundStyle(colorForLogLevel(log.level))
                                    Text(log.message)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Summary Card

    private func summaryCard(_ session: CoworkSession) -> some View {
        let summary = session.summary

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Session Complete")
                    .font(.headline)
            }

            Divider()

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                summaryItem(label: "Steps", value: "\(summary.completedSteps)/\(summary.totalSteps)", icon: "list.bullet")
                summaryItem(label: "Artifacts", value: "\(summary.finalArtifacts)", icon: "doc.on.doc")
                summaryItem(label: "Duration", value: formatDuration(summary.duration), icon: "clock")
                summaryItem(label: "Success Rate", value: "\(Int(summary.successRate * 100))%", icon: "chart.pie")
                summaryItem(label: "Files Accessed", value: "\(summary.filesAccessed)", icon: "folder")
                summaryItem(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: summary.totalSize, countStyle: .file), icon: "doc.badge.arrow.up")
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private func summaryItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Active Task", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Enter an instruction below to start a new task")
        }
    }

    // MARK: - Helpers

    private func colorForStepStatus(_ status: CoworkStep.StepStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }

    private func colorForLogLevel(_ level: CoworkStep.LogEntry.LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .debug: return .secondary
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3_600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration / 3_600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3_600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

#Preview {
    CoworkProgressView()
        .frame(width: 600, height: 800)
}

#endif
