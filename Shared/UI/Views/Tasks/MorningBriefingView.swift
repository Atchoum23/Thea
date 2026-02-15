import SwiftUI

// MARK: - Morning Briefing View

/// Displays the daily morning briefing with sections for calendar, tasks, health, and finance.
struct MorningBriefingView: View {
    @StateObject private var engine = MorningBriefingEngine.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TheaSpacing.lg) {
                // Header
                headerSection

                if engine.isGenerating {
                    ProgressView("Generating briefing...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, TheaSpacing.xxl)
                } else if let briefing = engine.latestBriefing {
                    briefingContent(briefing)
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Morning Briefing")
        .task {
            engine.loadSavedBriefing()
            await engine.generateIfNeeded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(TemporalValidator.timeOfDayGreeting())
                    .font(.largeTitle.bold())
                Text(TemporalValidator.formattedToday())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await engine.generate() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh briefing")
        }
    }

    // MARK: - Content

    private func briefingContent(_ briefing: DailyBriefing) -> some View {
        VStack(alignment: .leading, spacing: TheaSpacing.lg) {
            ForEach(briefing.sections) { section in
                sectionView(section)
            }
        }
    }

    private func sectionView(_ section: BriefingSection) -> some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: section.icon)
                    .foregroundStyle(.accent)
                Text(section.title)
                    .font(.headline)
            }

            ForEach(section.items) { item in
                HStack(alignment: .top, spacing: TheaSpacing.sm) {
                    Circle()
                        .fill(priorityColor(item.priority))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    Text(item.text)
                        .font(.body)
                        .foregroundStyle(item.priority == .info ? .secondary : .primary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Briefing Yet", systemImage: "sun.max")
        } description: {
            Text("Enable daily briefings in Settings to receive a morning summary of your day.")
        } actions: {
            Button("Generate Now") {
                Task { await engine.generate() }
            }
        }
        .padding(.top, TheaSpacing.xxl)
    }

    // MARK: - Helpers

    private func priorityColor(_ priority: BriefingItemPriority) -> Color {
        switch priority {
        case .high: return Color.theaError
        case .normal: return Color.theaWarning
        case .info: return Color.theaSuccess
        }
    }
}
