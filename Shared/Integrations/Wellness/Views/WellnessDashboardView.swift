import SwiftUI

/// Main wellness dashboard view
public struct WellnessDashboardView: View {
    @State private var viewModel = WellnessViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading wellness data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    wellnessContent
                }

                if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle("Wellness")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await viewModel.refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.refreshData()
        }
    }

    // MARK: - Main Content

    private var wellnessContent: some View {
        VStack(spacing: 20) {
            // Circadian phase card
            circadianPhaseCard

            // Active session or start session
            if viewModel.activeSession != nil {
                activeSessionCard
            } else {
                startSessionSection
            }

            // Ambient audio section
            ambientAudioSection

            // Session history
            if !viewModel.sessionHistory.isEmpty {
                sessionHistorySection
            }

            // Session statistics
            if let stats = viewModel.sessionStats {
                sessionStatsSection(stats)
            }
        }
    }

    // MARK: - Circadian Phase Card

    private var circadianPhaseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(Color(hex: viewModel.currentPhase.color))

                Text("Circadian Phase")
                    .font(.headline)

                Spacer()

                Text(viewModel.currentPhase.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: viewModel.currentPhase.color).opacity(0.2))
                    .foregroundColor(Color(hex: viewModel.currentPhase.color))
                    .cornerRadius(8)
            }

            if let recommendations = viewModel.uiRecommendations {
                VStack(alignment: .leading, spacing: 8) {
                    recommendationRow(
                        icon: "sun.max",
                        label: "Brightness",
                        value: "\(Int(recommendations.brightness * 100))%"
                    )

                    recommendationRow(
                        icon: "moon.fill",
                        label: "Blue Light Filter",
                        value: "\(Int(recommendations.blueFilterIntensity * 100))%"
                    )

                    recommendationRow(
                        icon: "paintbrush.fill",
                        label: "Theme",
                        value: recommendations.suggestedTheme.displayName
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private func recommendationRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Active Session Card

    @ViewBuilder
    private var activeSessionCard: some View {
        // SAFETY: Safely unwrap activeSession to avoid force unwrap crashes
        if let session = viewModel.activeSession {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: session.mode.icon)
                        .foregroundColor(Color(hex: session.mode.color))

                    Text(session.mode.displayName)
                        .font(.headline)

                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.endFocusSession(completed: true)
                        }
                    }) {
                        Text("End Session")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.sessionElapsedTime)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        Spacer()

                        Text(viewModel.sessionTimeRemaining)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: viewModel.sessionProgress, total: 100)
                        .tint(Color(hex: session.mode.color))
                }
            }
            .padding()
            .background(Color(hex: session.mode.color).opacity(0.1))
            .cornerRadius(16)
        }
    }

    // MARK: - Start Session Section

    private var startSessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Focus Session")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(WellnessFocusMode.allCases, id: \.self) { mode in
                    FocusModeButton(mode: mode) {
                        Task {
                            await viewModel.startFocusSession(mode: mode)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ambient Audio Section

    private var ambientAudioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ambient Audio")
                    .font(.headline)

                Spacer()

                if viewModel.isPlayingAudio {
                    Button(action: {
                        Task {
                            await viewModel.stopAmbientAudio()
                        }
                    }) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if viewModel.isPlayingAudio, let audio = viewModel.currentAudio {
                HStack {
                    Image(systemName: audio.icon)
                        .foregroundColor(.blue)

                    Text(audio.displayName)
                        .font(.subheadline)

                    Spacer()

                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: Binding(
                        get: { viewModel.audioVolume },
                        set: { newValue in
                            Task {
                                await viewModel.updateAudioVolume(newValue)
                            }
                        }
                    ), in: 0 ... 1)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(AmbientAudio.allCases, id: \.self) { audio in
                        AmbientAudioButton(audio: audio) {
                            Task {
                                await viewModel.playAmbientAudio(audio)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Session History

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            ForEach(viewModel.sessionHistory.prefix(5)) { session in
                SessionHistoryRow(session: session)
            }
        }
    }

    // MARK: - Session Statistics

    private func sessionStatsSection(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                WellnessStatCard(
                    title: "Total Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "calendar"
                )

                WellnessStatCard(
                    title: "Completion Rate",
                    value: "\(Int(stats.completionRate))%",
                    icon: "checkmark.circle"
                )
            }

            HStack(spacing: 16) {
                WellnessStatCard(
                    title: "Total Time",
                    value: "\(stats.totalMinutes / 60)h \(stats.totalMinutes % 60)m",
                    icon: "clock"
                )

                WellnessStatCard(
                    title: "Completed",
                    value: "\(stats.completedSessions)",
                    icon: "checkmark.seal"
                )
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.red)

            Spacer()

            Button("Dismiss") {
                viewModel.errorMessage = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Focus Mode Button

private struct FocusModeButton: View {
    let mode: WellnessFocusMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: mode.color))

                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\(mode.recommendedDuration)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: mode.color).opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ambient Audio Button

private struct AmbientAudioButton: View {
    let audio: AmbientAudio
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: audio.icon)
                    .font(.title3)

                Text(audio.displayName)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session History Row

private struct SessionHistoryRow: View {
    let session: FocusSession

    var body: some View {
        HStack {
            Image(systemName: session.mode.icon)
                .foregroundColor(Color(hex: session.mode.color))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.mode.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(session.startDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let duration = session.actualDuration {
                Text("\(duration)m")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(session.completed ? .green : .red)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Wellness Stat Card

private struct WellnessStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WellnessDashboardView()
    }
}
