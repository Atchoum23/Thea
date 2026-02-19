// HealthInsightsView.swift
// THEA - Health Insights Overview
// Created by Claude - February 2026
//
// Top-level health insights view that presents category summaries
// and navigates to HealthInsightsDetailView for the full dashboard.

import SwiftUI
import os.log

private let logger = Logger(subsystem: "app.thea", category: "HealthInsightsOverview")

// MARK: - Health Insights Overview View

/// Overview of health insights with navigation to the detailed dashboard.
///
/// Displays a quick summary of key health categories (sleep, activity,
/// heart, nutrition) with status indicators, plus a prominent link to
/// ``HealthInsightsDetailView`` for the full analysis.
///
/// Named `HealthInsightsOverviewView` to avoid conflict with the coaching-
/// focused `HealthInsightsView` in `Shared/UI/Views/Settings/`.
@MainActor
public struct HealthInsightsOverviewView: View {
    @State private var viewModel = HealthInsightsOverviewViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.isAuthorized {
                    authorizationPrompt
                } else {
                    healthSummaryHeader
                    categoryCards
                    detailNavigationLink
                    recentHighlights
                }
            }
            .padding()
        }
        .navigationTitle("Health Insights")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadOverview()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading health data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Authorization Prompt

    private var authorizationPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.theaError)

            Text("Health Data Access Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Grant HealthKit access to see personalized health insights, trend analysis, and AI-powered recommendations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.requestAuthorization()
                }
            } label: {
                Label("Grant Access", systemImage: "heart.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Summary Header

    private var healthSummaryHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.overallScore / 100)
                    .stroke(
                        scoreColor(viewModel.overallScore),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: viewModel.overallScore)

                VStack(spacing: 2) {
                    Text("\(Int(viewModel.overallScore))")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(scoreColor(viewModel.overallScore))

                    Text("Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(scoreDescription(viewModel.overallScore))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category Cards

    private var categoryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            CategorySummaryCard(
                icon: "bed.double.fill",
                title: "Sleep",
                value: viewModel.sleepSummary,
                score: viewModel.sleepScore,
                color: .theaInfo
            )

            CategorySummaryCard(
                icon: "figure.walk",
                title: "Activity",
                value: viewModel.activitySummary,
                score: viewModel.activityScore,
                color: .theaSuccess
            )

            CategorySummaryCard(
                icon: "heart.fill",
                title: "Heart",
                value: viewModel.heartSummary,
                score: viewModel.heartScore,
                color: .theaError
            )

            CategorySummaryCard(
                icon: "flame.fill",
                title: "Nutrition",
                value: viewModel.nutritionSummary,
                score: viewModel.nutritionScore,
                color: .theaWarning
            )
        }
    }

    // MARK: - Detail Navigation

    private var detailNavigationLink: some View {
        NavigationLink {
            HealthInsightsDetailView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Health Dashboard")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Trends, AI insights, and correlations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Highlights

    private var recentHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Highlights")
                .font(.headline)

            if viewModel.highlights.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                    Text("No highlights yet. Keep tracking to see insights.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(viewModel.highlights) { highlight in
                    HighlightRow(highlight: highlight)
                }
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return Color.theaSuccess }
        if score >= 60 { return Color.theaWarning }
        return Color.theaError
    }

    private func scoreDescription(_ score: Double) -> String {
        if score >= 80 { return "Your health metrics look great" }
        if score >= 60 { return "Solid overall with room to improve" }
        if score >= 40 { return "Some areas need attention" }
        return "Focus on building healthier habits"
    }
}

// MARK: - Category Summary Card

private struct CategorySummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(1, score / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Highlight Row

private struct HighlightRow: View {
    let highlight: HealthHighlight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.icon)
                .font(.title3)
                .foregroundStyle(highlight.isPositive ? Color.theaSuccess : Color.theaWarning)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(highlight.detail)
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

// MARK: - Health Highlight Model

struct HealthHighlight: Identifiable, Sendable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let isPositive: Bool
}

// MARK: - View Model

@MainActor
@Observable
final class HealthInsightsOverviewViewModel {
    var isLoading = false
    var isAuthorized = false

    var overallScore: Double = 0
    var sleepScore: Double = 0
    var activityScore: Double = 0
    var heartScore: Double = 0
    var nutritionScore: Double = 0

    var sleepSummary: String = "--"
    var activitySummary: String = "--"
    var heartSummary: String = "--"
    var nutritionSummary: String = "--"

    var highlights: [HealthHighlight] = []

    private let healthKitService = HealthKitService()

    func loadOverview() async {
        isLoading = true
        defer { isLoading = false }

        do {
            isAuthorized = try await healthKitService.requestAuthorization()
            guard isAuthorized else { return }
            await fetchLatestMetrics()
        } catch {
            logger.error("Failed to authorize HealthKit: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        do {
            isAuthorized = try await healthKitService.requestAuthorization()
            if isAuthorized {
                await fetchLatestMetrics()
            }
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        guard isAuthorized else { return }
        isLoading = true
        defer { isLoading = false }
        await fetchLatestMetrics()
    }

    private func fetchLatestMetrics() async {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        // Fetch sleep
        let sleepRange = DateInterval(start: weekAgo.addingTimeInterval(-30 * 3600), end: now)
        var avgSleepMinutes = 0
        if let records = try? await healthKitService.fetchSleepData(for: sleepRange) { // Safe: nil = no sleep data, view shows dashes
            let minutes = records.map { $0.endDate.timeIntervalSince($0.startDate) / 60 }
            avgSleepMinutes = minutes.isEmpty ? 0 : Int(minutes.reduce(0, +) / Double(minutes.count))
            sleepScore = min(100, Double(avgSleepMinutes) / 480 * 100)
            let h = avgSleepMinutes / 60
            let m = avgSleepMinutes % 60
            sleepSummary = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }

        // Fetch activity (last 7 days)
        var totalSteps = 0
        var totalCalories = 0
        var dayCount = 0
        for offset in 0 ..< 7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            if let summary = try? await healthKitService.fetchActivityData(for: date) { // Safe: nil = no activity for this day, skip
                totalSteps += summary.steps
                totalCalories += summary.activeCalories
                dayCount += 1
            }
        }
        let avgSteps = dayCount > 0 ? totalSteps / dayCount : 0
        let avgCalories = dayCount > 0 ? totalCalories / dayCount : 0
        activityScore = min(100, Double(avgSteps) / 10000 * 100)
        activitySummary = "\(avgSteps) steps"

        // Fetch heart rate
        let hrRange = DateInterval(start: weekAgo, end: now)
        var avgRestingHR = 0
        if let hrRecords = try? await healthKitService.fetchHeartRateData(for: hrRange) { // Safe: nil = no HR data, view shows dashes
            let resting = hrRecords.filter { $0.context == .resting || $0.context == .sleep }
            avgRestingHR = resting.isEmpty ? 0 : resting.map(\.beatsPerMinute).reduce(0, +) / resting.count
            heartScore = avgRestingHR > 0 ? min(100, max(0, 100 - Double(avgRestingHR - 50))) : 0
            heartSummary = avgRestingHR > 0 ? "\(avgRestingHR) BPM" : "--"
        }

        // Nutrition score (proxy from calorie balance)
        // periphery:ignore - Reserved: avgCalories parameter — kept for API compatibility
        let calorieBalance = avgCalories > 0
            ? min(100.0, Double(avgCalories) / 500.0 * 100.0)
            : 0.0
        nutritionScore = calorieBalance
        nutritionSummary = avgCalories > 0 ? "\(avgCalories) cal" : "--"

        // Overall
        overallScore = (sleepScore + activityScore + heartScore + nutritionScore) / 4

        // Generate highlights
        generateHighlights(
            avgSleepMinutes: avgSleepMinutes,
            avgSteps: avgSteps,
            avgRestingHR: avgRestingHR,
            avgCalories: avgCalories
        )
    }

    // periphery:ignore:parameters avgCalories - Reserved: parameter(s) kept for API compatibility
    private func generateHighlights(
        avgSleepMinutes: Int,
        avgSteps: Int,
        avgRestingHR: Int,
        // periphery:ignore - Reserved: avgCalories parameter kept for API compatibility
        avgCalories: Int
    ) {
        var result: [HealthHighlight] = []

        if avgSleepMinutes >= 420 {
            result.append(HealthHighlight(
                icon: "bed.double.fill",
                title: "Good Sleep",
                detail: "Averaging \(avgSleepMinutes / 60)h \(avgSleepMinutes % 60)m -- meeting the 7-hour target",
                isPositive: true
            ))
        } else if avgSleepMinutes > 0 {
            result.append(HealthHighlight(
                icon: "bed.double.fill",
                title: "Sleep Below Target",
                detail: "Averaging \(avgSleepMinutes / 60)h \(avgSleepMinutes % 60)m -- aim for 7+ hours",
                isPositive: false
            ))
        }

        if avgSteps >= 10000 {
            result.append(HealthHighlight(
                icon: "figure.walk",
                title: "Step Goal Met",
                detail: "Averaging \(avgSteps) steps daily",
                isPositive: true
            ))
        } else if avgSteps > 0 {
            result.append(HealthHighlight(
                icon: "figure.walk",
                title: "Room for Activity",
                detail: "Averaging \(avgSteps) steps -- aim for 10,000",
                isPositive: false
            ))
        }

        if avgRestingHR > 0 && avgRestingHR < 70 {
            result.append(HealthHighlight(
                icon: "heart.fill",
                title: "Healthy Heart Rate",
                detail: "Resting HR of \(avgRestingHR) BPM indicates good fitness",
                isPositive: true
            ))
        } else if avgRestingHR >= 80 {
            result.append(HealthHighlight(
                icon: "heart.fill",
                title: "Elevated Heart Rate",
                detail: "Resting HR of \(avgRestingHR) BPM -- consider cardio exercise",
                isPositive: false
            ))
        }

        highlights = result
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthInsightsOverviewView()
    }
}
