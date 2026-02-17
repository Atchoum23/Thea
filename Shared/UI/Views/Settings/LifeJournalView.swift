// LifeJournalView.swift
// Thea — Ambient Life Journal Browser
//
// Displays auto-generated daily narratives from passive life data.
// Each day's entry summarizes sleep, productivity, health, weather, mood,
// and notable events in natural language.

import SwiftUI

struct LifeJournalView: View {
    @State private var journal = AmbientLifeJournal.shared
    @State private var selectedEntry: JournalEntry?
    @State private var searchText = ""
    @State private var isGenerating = false

    private var displayedEntries: [JournalEntry] {
        if searchText.isEmpty {
            return journal.entries.sorted { $0.date > $1.date }
        }
        return journal.searchEntries(query: searchText).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                todaySection
                Divider()
                pastEntriesSection
            }
            .padding()
        }
        .navigationTitle("Life Journal")
        .searchable(text: $searchText, prompt: "Search journal entries...")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.pages")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Ambient Life Journal")
                    .font(.title2.bold())
                Spacer()
                Text("\(journal.entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Automatically generated daily narratives from your life data. No input required.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        GroupBox("Today") {
            if let today = journal.todayEntry {
                entryContent(today)
            } else {
                VStack(spacing: 12) {
                    Text("No entry for today yet")
                        .foregroundStyle(.secondary)
                    Button {
                        generateToday()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Generate Today's Entry", systemImage: "sparkles")
                        }
                    }
                    .disabled(isGenerating)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Past Entries

    private var pastEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Entries")
                .font(.headline)

            if displayedEntries.isEmpty {
                Text("No journal entries yet. Entries are generated automatically at the end of each day.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(displayedEntries) { entry in
                    entryCard(entry)
                }
            }
        }
    }

    // MARK: - Entry Card

    private func entryCard(_ entry: JournalEntry) -> some View {
        GroupBox {
            entryContent(entry)
        } label: {
            HStack {
                Text(entry.date, style: .date)
                    .font(.headline)
                Spacer()
                if let mood = entry.mood {
                    moodIndicator(mood)
                }
            }
        }
    }

    private func entryContent(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.narrative)
                .font(.body)
                .lineSpacing(4)

            if !entry.highlights.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Highlights")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(entry.highlights, id: \.self) { highlight in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(highlight)
                                .font(.caption)
                        }
                    }
                }
            }

            metricsRow(entry.metrics)

            if let annotation = entry.userAnnotation, !annotation.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.blue)
                    Text(annotation)
                        .font(.caption)
                        .italic()
                }
            }
        }
    }

    // MARK: - Metrics Row

    private func metricsRow(_ metrics: JournalMetrics) -> some View {
        HStack(spacing: 16) {
            if let sleep = metrics.sleepHours {
                metricPill(icon: "bed.double.fill", value: String(format: "%.1fh", sleep), color: .purple)
            }
            if let steps = metrics.stepCount {
                metricPill(icon: "figure.walk", value: "\(steps)", color: .green)
            }
            if let exercise = metrics.exerciseMinutes {
                metricPill(icon: "flame.fill", value: "\(exercise)m", color: .orange)
            }
            if let deepWork = metrics.deepWorkMinutes {
                metricPill(icon: "brain.head.profile", value: "\(deepWork)m", color: .blue)
            }
            if let weather = metrics.weatherSummary {
                metricPill(icon: "cloud.sun.fill", value: weather, color: .cyan)
            }
            Spacer()
        }
        .font(.caption)
    }

    private func metricPill(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Mood Indicator

    private func moodIndicator(_ mood: Double) -> some View {
        let emoji: String
        let label: String
        switch mood {
        case 0..<0.2: emoji = "😔"; label = "Low"
        case 0.2..<0.4: emoji = "😐"; label = "Below Avg"
        case 0.4..<0.6: emoji = "🙂"; label = "Neutral"
        case 0.6..<0.8: emoji = "😊"; label = "Good"
        default: emoji = "😄"; label = "Great"
        }
        return HStack(spacing: 4) {
            Text(emoji)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func generateToday() {
        isGenerating = true
        Task { @MainActor in
            _ = await journal.generateDailyEntry()
            isGenerating = false
        }
    }
}
