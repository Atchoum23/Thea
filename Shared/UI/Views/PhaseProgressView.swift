// PhaseProgressView.swift
import SwiftUI

@MainActor
public struct PhaseProgressView: View {
    @State private var progress: ExecutionProgress?
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading progress...")
            } else if let progress = progress {
                progressDetails(for: progress)
            } else {
                noProgressView
            }
        }
        .padding()
        .navigationTitle("Phase Progress")
        .task {
            await loadProgress()
        }
    }

    // MARK: - Views

    private func progressDetails(for progress: ExecutionProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status Badge
            HStack {
                Text(progress.status.rawValue)
                    .font(.headline)
                    .foregroundStyle(statusColor(for: progress.status))

                Spacer()

                Text("Phase \(progress.phaseId.replacingOccurrences(of: "phase", with: ""))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Progress Stats
            VStack(alignment: .leading, spacing: 12) {
                statRow(label: "Files Completed", value: "\(progress.filesCompleted.count)")
                statRow(label: "Files Failed", value: "\(progress.filesFailed.count)")
                statRow(label: "Current File Index", value: "\(progress.currentFileIndex)")

                if !progress.filesCompleted.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed Files:")
                            .font(.caption.bold())
                        ForEach(progress.filesCompleted, id: \.self) { file in
                            Text("✓ \(file)")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                if !progress.filesFailed.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Failed Files:")
                            .font(.caption.bold())
                        ForEach(progress.filesFailed, id: \.self) { file in
                            Text("✗ \(file)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Divider()

            // Timing Information
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing")
                    .font(.subheadline.bold())

                statRow(label: "Started", value: formatDate(progress.startTime))
                statRow(label: "Last Update", value: formatDate(progress.lastUpdateTime))
                statRow(label: "Duration", value: formatDuration(from: progress.startTime))
            }

            if !progress.errorLog.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Error Log")
                        .font(.subheadline.bold())

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(progress.errorLog, id: \.self) { error in
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }

    private var noProgressView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Active Phase")
                .font(.headline)

            Text("Start a phase from the Self-Execution view")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: ExecutionProgress.ExecutionStatus) -> Color {
        switch status {
        case .notStarted:
            return .secondary
        case .inProgress:
            return .blue
        case .waitingForApproval:
            return .orange
        case .paused:
            return .yellow
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(from startDate: Date) -> String {
        let duration = Date().timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }

    private func loadProgress() async {
        isLoading = true
        progress = await ProgressTracker.shared.loadProgress()
        isLoading = false
    }
}
