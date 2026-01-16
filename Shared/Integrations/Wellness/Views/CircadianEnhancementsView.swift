import SwiftUI

/// Enhanced circadian rhythm view with dynamic UI adaptation
@MainActor
public struct CircadianEnhancementsView: View {
    @State private var viewModel = CircadianViewModel()
    @State private var currentPhase: CircadianPhase = .morning

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Phase Card
                currentPhaseCard

                // Circadian Clock Visualization
                clockVisualization

                // Phase Timeline
                phaseTimeline

                // Recommendations
                recommendationsSection

                // UI Theme Preview
                themePreviewSection
            }
            .padding(.vertical)
        }
        .background(circadianBackgroundGradient)
        .navigationTitle("Circadian Rhythm")
        .task {
            await updateCircadianPhase()
        }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await updateCircadianPhase()
            }
        }
    }

    // MARK: - Current Phase Card

    private var currentPhaseCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: currentPhase.iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(currentPhase.primaryColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentPhase.displayName)
                        .font(.title2)
                        .bold()

                    Text(currentPhase.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Time Until Next Phase
            if let nextPhase = viewModel.nextPhase {
                HStack {
                    Text("Next phase:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(nextPhase.displayName)
                        .font(.caption)
                        .bold()

                    Spacer()

                    Text("in \(viewModel.timeUntilNextPhase)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(currentPhase.primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(currentPhase.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Clock Visualization

    private var clockVisualization: some View {
        VStack(spacing: 12) {
            Text("24-Hour Circadian Clock")
                .font(.headline)
                .padding(.horizontal)

            ZStack {
                // Clock face
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 280, height: 280)

                // Phase segments
                ForEach(CircadianPhase.allCases, id: \.self) { phase in
                    phaseSegment(phase)
                }

                // Current time indicator
                currentTimeIndicator

                // Center dot
                Circle()
                    .fill(Color.primary)
                    .frame(width: 12, height: 12)
            }
            .padding()
        }
    }

    private func phaseSegment(_ phase: CircadianPhase) -> some View {
        let startAngle = angleForHour(phase.startHour)
        let endAngle = angleForHour(phase.endHour)

        return Circle()
            .trim(from: startAngle / 360, to: endAngle / 360)
            .stroke(phase.primaryColor.opacity(0.6), lineWidth: 30)
            .frame(width: 240, height: 240)
            .rotationEffect(.degrees(-90))
    }

    private var currentTimeIndicator: some View {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentMinute = Calendar.current.component(.minute, from: Date())
        let angle = angleForTime(hour: currentHour, minute: currentMinute)

        return Rectangle()
            .fill(Color.primary)
            .frame(width: 3, height: 100)
            .offset(y: -50)
            .rotationEffect(.degrees(angle))
    }

    // MARK: - Phase Timeline

    private var phaseTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Phase Schedule")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(CircadianPhase.allCases, id: \.self) { phase in
                    PhaseTimelineRow(
                        phase: phase,
                        isCurrent: phase == currentPhase
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Phase Recommendations")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(currentPhase.recommendations, id: \.self) { recommendation in
                    RecommendationCard(
                        icon: recommendation.icon,
                        title: recommendation.title,
                        description: recommendation.description,
                        color: currentPhase.primaryColor
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Theme Preview

    private var themePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UI Theme Adaptation")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 16) {
                Text("Current theme automatically adapts based on circadian phase")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    ForEach(CircadianPhase.allCases, id: \.self) { phase in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: phase.themeColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            phase == currentPhase ? Color.primary : Color.clear,
                                            lineWidth: 3
                                        )
                                )

                            Text(phase.shortName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Background Gradient

    private var circadianBackgroundGradient: some View {
        LinearGradient(
            colors: currentPhase.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(0.1)
        .ignoresSafeArea()
    }

    // MARK: - Helper Functions

    private func angleForHour(_ hour: Int) -> Double {
        Double(hour) * 15.0 // 360 / 24 = 15 degrees per hour
    }

    private func angleForTime(hour: Int, minute: Int) -> Double {
        let totalMinutes = Double(hour * 60 + minute)
        return (totalMinutes / 1440.0) * 360.0 // 1440 minutes in a day
    }

    private func updateCircadianPhase() async {
        let hour = Calendar.current.component(.hour, from: Date())
        currentPhase = CircadianPhase.phaseForHour(hour)
        await viewModel.updateCurrentPhase(currentPhase)
    }
}

// MARK: - Phase Timeline Row

private struct PhaseTimelineRow: View {
    let phase: CircadianPhase
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Phase indicator
            Circle()
                .fill(phase.primaryColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: isCurrent ? 2 : 0)
                        .frame(width: 20, height: 20)
                )

            // Phase info
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.displayName)
                    .font(.subheadline)
                    .bold(isCurrent)

                Text("\(phase.timeRange)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Current indicator
            if isCurrent {
                Text("NOW")
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(phase.primaryColor.opacity(0.2))
                    .foregroundStyle(phase.primaryColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrent ? phase.primaryColor.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Circadian Phase Model



// MARK: - ViewModel

@MainActor
@Observable
final class CircadianViewModel {
    var currentPhase: CircadianPhase = .morning
    var nextPhase: CircadianPhase?
    var timeUntilNextPhase: String = ""

    func updateCurrentPhase(_ phase: CircadianPhase) async {
        currentPhase = phase
        calculateNextPhase()
    }

    private func calculateNextPhase() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentMinute = Calendar.current.component(.minute, from: Date())

        let allPhases = CircadianPhase.allCases
        guard let currentIndex = allPhases.firstIndex(of: currentPhase) else { return }

        nextPhase = allPhases[(currentIndex + 1) % allPhases.count]

        if let next = nextPhase {
            let nextHour = next.startHour
            let hoursUntil = nextHour > currentHour ? nextHour - currentHour : (24 - currentHour) + nextHour
            let minutesUntil = 60 - currentMinute

            if hoursUntil == 0 {
                timeUntilNextPhase = "\(minutesUntil)m"
            } else if minutesUntil == 60 {
                timeUntilNextPhase = "\(hoursUntil)h"
            } else {
                timeUntilNextPhase = "\(hoursUntil)h \(minutesUntil)m"
            }
        }
    }
}

#Preview {
    NavigationStack {
        CircadianEnhancementsView()
    }
}
