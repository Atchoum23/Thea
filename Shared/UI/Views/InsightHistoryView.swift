// InsightHistoryView.swift
// Thea — Insight History & Feedback UI
//
// Browse all delivered proactive insights, provide feedback, and view
// weekly digests. Part of Phase Q3: Proactive Intelligence Complete.

import SwiftData
import SwiftUI

// MARK: - Insight History View

struct InsightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DeliveredInsight.deliveredAt, order: .reverse) private var insights: [DeliveredInsight]

    @State private var selectedCategory: DeliveredInsightCategory?
    @State private var showOnlyUnreviewed = false
    @State private var searchText = ""

    private var filtered: [DeliveredInsight] {
        insights.filter { insight in
            let catMatch = selectedCategory == nil || insight.category == selectedCategory
            let reviewMatch = !showOnlyUnreviewed || insight.userFeedback == nil
            let searchMatch = searchText.isEmpty ||
                insight.title.localizedCaseInsensitiveContains(searchText) ||
                insight.body.localizedCaseInsensitiveContains(searchText)
            return catMatch && reviewMatch && searchMatch
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("Insight History")
        } detail: {
            detailContent
        }
        .searchable(text: $searchText, prompt: "Search insights")
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List {
            Section("Filter") {
                Button {
                    selectedCategory = nil
                    showOnlyUnreviewed = false
                } label: {
                    HStack {
                        Label("All Insights", systemImage: "tray.full")
                        Spacer()
                        Text("\(insights.count)").foregroundStyle(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showOnlyUnreviewed.toggle()
                    selectedCategory = nil
                } label: {
                    HStack {
                        Label("Unreviewed", systemImage: "bell.badge")
                            .foregroundStyle(showOnlyUnreviewed ? .accentColor : .primary)
                        Spacer()
                        Text("\(insights.filter { $0.userFeedback == nil }.count)")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Categories") {
                ForEach(DeliveredInsightCategory.allCases, id: \.self) { cat in
                    Button {
                        selectedCategory = cat == selectedCategory ? nil : cat
                        showOnlyUnreviewed = false
                    } label: {
                        HStack {
                            Label(cat.rawValue, systemImage: cat.symbolName)
                                .foregroundStyle(selectedCategory == cat ? .accentColor : .primary)
                            Spacer()
                            Text("\(insights.filter { $0.category == cat }.count)")
                                .foregroundStyle(.secondary).font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Feedback summary
            let feedbackGiven = insights.filter { $0.userFeedback != nil }
            if !feedbackGiven.isEmpty {
                Section("Feedback Summary") {
                    feedbackSummaryRow
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    private var feedbackSummaryRow: some View {
        let helpful = insights.filter { $0.userFeedback == .helpful }.count
        let notRelevant = insights.filter { $0.userFeedback == .notRelevant }.count
        let dismissed = insights.filter { $0.userFeedback == .dismissed }.count
        let total = helpful + notRelevant + dismissed

        return VStack(alignment: .leading, spacing: 4) {
            if total > 0 {
                HStack {
                    Text("👍").font(.caption); Text("\(helpful)").font(.caption2)
                    Spacer()
                    Text("👎").font(.caption); Text("\(notRelevant)").font(.caption2)
                    Spacer()
                    Text("✖").font(.caption); Text("\(dismissed)").font(.caption2)
                }
            }
            ProgressView(value: total > 0 ? Double(helpful) / Double(total) : 0)
                .tint(.green)
            Text("\(total > 0 ? Int(Double(helpful) / Double(total) * 100) : 0)% rated helpful")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if filtered.isEmpty {
            ContentUnavailableView(
                "No Insights",
                systemImage: "lightbulb.slash",
                description: Text(insights.isEmpty ? "Proactive insights will appear here as Thea analyzes your patterns." : "No insights match the current filter.")
            )
        } else {
            insightList
        }
    }

    private var insightList: some View {
        List {
            ForEach(filtered) { insight in
                InsightRow(insight: insight)
            }
            .onDelete { offsets in
                for offset in offsets {
                    modelContext.delete(filtered[offset])
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    @Bindable var insight: DeliveredInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: insight.category.symbolName)
                    .foregroundStyle(.tint)
                Text(insight.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if insight.actionTaken {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
            }

            // Body
            Text(insight.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Footer
            HStack {
                Label(insight.source.rawValue, systemImage: insight.source.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(insight.deliveredAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Feedback buttons
            if insight.userFeedback == nil {
                FeedbackButtons(insight: insight)
            } else {
                feedbackBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var feedbackBadge: some View {
        let text: String
        let color: Color

        switch insight.userFeedback {
        case .helpful:    (text, color) = ("Helpful", .green)
        case .notRelevant: (text, color) = ("Not Relevant", .orange)
        case .dismissed:  (text, color) = ("Dismissed", .gray)
        case nil:         (text, color) = ("", .clear)
        }

        return Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Feedback Buttons

struct FeedbackButtons: View {
    @Bindable var insight: DeliveredInsight

    var body: some View {
        HStack(spacing: 8) {
            feedbackButton("👍 Helpful", feedback: .helpful, color: .green)
            feedbackButton("👎 Not Relevant", feedback: .notRelevant, color: .orange)
            feedbackButton("✖ Dismiss", feedback: .dismissed, color: .gray)
        }
    }

    private func feedbackButton(_ label: String, feedback: InsightFeedback, color: Color) -> some View {
        Button(label) {
            withAnimation {
                insight.userFeedback = feedback
                // Record action taken if user says helpful
                if feedback == .helpful {
                    insight.actionTaken = true
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(color)
    }
}

// MARK: - Preview

#Preview {
    InsightHistoryView()
        .modelContainer(for: DeliveredInsight.self, inMemory: true)
}
