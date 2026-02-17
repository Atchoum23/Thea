// HealthInsightsView.swift
// Thea — Health Coaching Insights Dashboard

import SwiftUI
import os.log

struct HealthInsightsView: View {
    private let pipeline = HealthCoachingPipeline.shared
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overallScoreSection; insightsSection; statusSection; actionsSection
            }.padding()
        }
        .navigationTitle("Health Insights")
    }

    // MARK: - Overall Score
    private var overallScoreSection: some View {
        Section {
            if let report = pipeline.lastAnalysis {
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(scoreColor(report.overallScore).opacity(0.2), lineWidth: 10)
                        Circle().trim(from: 0, to: report.overallScore)
                            .stroke(scoreColor(report.overallScore), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(Int(report.overallScore * 100))").font(.theaTitle1).foregroundStyle(scoreColor(report.overallScore))
                            Text("/ 100").font(.theaCaption2).foregroundStyle(.secondary)
                        }
                    }.frame(width: 100, height: 100)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scoreLabel(report.overallScore)).font(.theaTitle3).foregroundStyle(scoreColor(report.overallScore))
                        Text("Based on \(report.dataPoints.count) data point(s)").font(.theaCaption1).foregroundStyle(.secondary)
                        Text(report.date.formatted(.dateTime.month().day().hour().minute())).font(.theaCaption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "heart.text.clipboard").font(.title).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("No analysis yet").font(.theaBody)
                        Text("Run an analysis to see your health score").font(.theaCaption1).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        } header: { Text("Health Score").font(.theaHeadline) }
    }

    // MARK: - Insights
    private var insightsSection: some View {
        Section {
            if pipeline.activeInsights.isEmpty {
                Text("No active insights. Run an analysis or check back later.").font(.theaCaption1).foregroundStyle(.secondary)
            } else {
                ForEach(pipeline.activeInsights) { insight in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: sevIcon(insight.severity)).foregroundStyle(sevColor(insight.severity))
                            Text(insight.title).font(.theaBody)
                            Spacer()
                            Button { pipeline.dismissInsight(insight.id) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }.buttonStyle(.plain)
                        }
                        Text(insight.message).font(.theaCaption1).foregroundStyle(.secondary)
                        if !insight.suggestion.isEmpty {
                            Label(insight.suggestion, systemImage: "lightbulb.fill").font(.theaCaption2).foregroundStyle(.orange)
                        }
                        Text(insight.category.rawValue.capitalized).font(.system(size: 10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(sevColor(insight.severity).opacity(0.12), in: Capsule())
                    }
                    .padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        } header: {
            HStack {
                Text("Active Insights (\(pipeline.activeInsights.count))").font(.theaHeadline)
                Spacer()
                if !pipeline.activeInsights.isEmpty {
                    Button("Clear All") { pipeline.clearAllInsights() }.font(.theaCaption1)
                }
            }
        }
    }

    // MARK: - Status
    private var statusSection: some View {
        Section {
            HStack(spacing: 16) {
                LabeledContent("Coaching") { Text(pipeline.isEnabled ? "Enabled" : "Disabled").foregroundStyle(pipeline.isEnabled ? .green : .red) }
                LabeledContent("Cooldown") { Text("\(pipeline.analysisCooldownHours)h") }
                LabeledContent("Last Run") {
                    if let d = pipeline.lastAnalysisDate {
                        Text(d.formatted(.relative(presentation: .named)))
                    } else {
                        Text("Never").foregroundStyle(.secondary)
                    }
                }
            }.font(.theaCaption1)
        } header: { Text("Status").font(.theaHeadline) }
    }

    // MARK: - Actions
    private var actionsSection: some View {
        Section {
            HStack {
                Button {
                    isRunning = true
                    Task { await pipeline.runAnalysis(); isRunning = false }
                } label: {
                    Label(isRunning ? "Analyzing..." : "Run Analysis", systemImage: isRunning ? "arrow.triangle.2.circlepath" : "play.fill")
                }.disabled(isRunning || pipeline.isAnalyzing)
                Spacer()
            }
        } header: { Text("Actions").font(.theaHeadline) }
    }

    // MARK: - Helpers
    private func scoreColor(_ s: Double) -> Color {
        switch s { case 0.8...: .green; case 0.6..<0.8: .blue; case 0.4..<0.6: .orange; default: .red }
    }

    private func scoreLabel(_ s: Double) -> String {
        switch s { case 0.8...: "Excellent"; case 0.6..<0.8: "Good"; case 0.4..<0.6: "Fair"; default: "Needs Attention" }
    }

    private func sevIcon(_ s: CoachingSeverity) -> String {
        switch s { case .critical: "exclamationmark.triangle.fill"; case .warning: "exclamationmark.circle.fill"; case .info: "info.circle.fill"; case .positive: "checkmark.circle.fill" }
    }

    private func sevColor(_ s: CoachingSeverity) -> Color {
        switch s { case .critical: .red; case .warning: .orange; case .info: .blue; case .positive: .green }
    }
}

#Preview { HealthInsightsView().frame(width: 600, height: 550) }
