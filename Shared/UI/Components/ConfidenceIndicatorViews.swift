// ConfidenceIndicatorViews.swift
// Thea
//
// SwiftUI components for displaying AI confidence levels
// Three-level system with progressive disclosure

import SwiftUI

// MARK: - Confidence Badge (Primary Display)

/// Compact confidence badge for inline display in chat messages
public struct ConfidenceBadge: View {
    let result: ConfidenceResult
    @State private var isExpanded = false

    public init(result: ConfidenceResult) {
        self.result = result
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: result.level.icon)
                    .font(.caption)
                Text(result.level.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)

                if result.decomposition.hasConflicts {
                    Image(systemName: "exclamationmark.2")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(levelColor.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(levelColor.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(levelColor)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isExpanded) {
            ConfidenceDetailView(result: result)
                .frame(minWidth: 320, maxWidth: 400)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confidence level")
        .accessibilityValue("\(result.level.rawValue), \(Int(result.overallConfidence * 100)) percent")
        .accessibilityHint("Double tap to see confidence breakdown")
    }

    private var levelColor: Color {
        switch result.level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .unverified: return .gray
        }
    }
}

// MARK: - Confidence Detail View

/// Expanded view showing full confidence breakdown
public struct ConfidenceDetailView: View {
    let result: ConfidenceResult
    @Environment(\.dismiss) private var dismiss

    public init(result: ConfidenceResult) {
        self.result = result
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Source breakdown
                sourceBreakdownSection

                // Decomposition factors
                if !result.decomposition.factors.isEmpty {
                    factorsSection
                }

                // Conflicts
                if result.decomposition.hasConflicts {
                    conflictsSection
                }

                // Suggestions
                if !result.decomposition.suggestions.isEmpty {
                    suggestionsSection
                }
            }
            .padding()
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    private var headerSection: some View {
        HStack {
            ConfidenceGauge(confidence: result.overallConfidence, size: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.level.rawValue)
                    .font(.headline)

                Text("\(Int(result.overallConfidence * 100))% overall confidence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(result.reasoning)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification Sources")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(result.sources) { source in
                SourceConfidenceRow(source: source)
            }
        }
    }

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contributing Factors")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(result.decomposition.factors) { factor in
                ConfidenceFactorRow(factor: factor)
            }
        }
    }

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Conflicts Detected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ForEach(result.decomposition.conflicts) { conflict in
                ConflictRow(conflict: conflict)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
        )
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestions to Improve Confidence")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(result.decomposition.suggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Source Confidence Row

struct SourceConfidenceRow: View {
    let source: ConfidenceSource

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            Image(systemName: source.icon)
                .frame(width: 20)
                .foregroundStyle(source.verified ? .green : .secondary)

            // Source info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(source.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if source.verified {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                Text(source.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Confidence bar + percentage
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(source.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorForConfidence(source.confidence))

                ConfidenceMiniBar(confidence: source.confidence)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForConfidence(_ confidence: Double) -> Color {
        switch confidence {
        case 0.85...1.0: return .green
        case 0.60..<0.85: return .orange
        default: return .red
        }
    }
}

// MARK: - Factor Row

struct ConfidenceFactorRow: View {
    let factor: ConfidenceDecomposition.DecompositionFactor

    var body: some View {
        HStack(spacing: 8) {
            // Contribution indicator
            Image(systemName: factor.contribution >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(factor.contribution >= 0 ? .green : .red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(factor.explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Contribution value
            Text(String(format: "%+.0f%%", factor.contribution * 50))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(factor.contribution >= 0 ? .green : .red)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Conflict Row

struct ConflictRow: View {
    let conflict: ConfidenceDecomposition.ConflictInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(conflict.source1) vs \(conflict.source2)")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(conflict.severity.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.2))
                    .foregroundStyle(severityColor)
                    .cornerRadius(4)
            }

            Text(conflict.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .minor: return .yellow
        case .moderate: return .orange
        case .major: return .red
        }
    }
}

// MARK: - Confidence Gauge

/// Circular confidence gauge for prominent display
public struct ConfidenceGauge: View {
    let confidence: Double
    let size: CGFloat
    var showLabel: Bool = true

    public init(confidence: Double, size: CGFloat = 60, showLabel: Bool = true) {
        self.confidence = confidence
        self.size = size
        self.showLabel = showLabel
    }

    private var level: ConfidenceLevel {
        ConfidenceLevel(from: confidence)
    }

    private var color: Color {
        switch level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .unverified: return .gray
        }
    }

    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    color.opacity(0.2),
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: confidence)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: confidence)

            // Center content
            VStack(spacing: 2) {
                if showLabel {
                    Text("\(Int(confidence * 100))")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.system(size: size * 0.14))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: level.icon)
                        .font(.system(size: size * 0.35))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence gauge")
        .accessibilityValue("\(Int(confidence * 100)) percent, \(level.rawValue)")
    }
}

// MARK: - Mini Progress Bar

/// Compact horizontal confidence bar
public struct ConfidenceMiniBar: View {
    let confidence: Double

    public init(confidence: Double) {
        self.confidence = confidence
    }

    private var color: Color {
        switch confidence {
        case 0.85...1.0: return .green
        case 0.60..<0.85: return .orange
        default: return .red
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.2))

                // Progress
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geometry.size.width * confidence)
                    .animation(.spring(response: 0.3), value: confidence)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Inline Confidence Indicator

/// Small inline indicator for use in lists or compact views
public struct ConfidenceIndicatorSmall: View {
    let level: ConfidenceLevel

    public init(level: ConfidenceLevel) {
        self.level = level
    }

    public init(confidence: Double) {
        self.level = ConfidenceLevel(from: confidence)
    }

    private var color: Color {
        switch level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .unverified: return .gray
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(shortLabel)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confidence: \(level.rawValue)")
    }

    private var shortLabel: String {
        switch level {
        case .high: return "High"
        case .medium: return "Med"
        case .low: return "Low"
        case .unverified: return "—"
        }
    }
}

// MARK: - Preview

#Preview("Confidence Badge") {
    VStack(spacing: 20) {
        ConfidenceBadge(result: ConfidenceResult(
            overallConfidence: 0.92,
            sources: [
                ConfidenceSource(
                    type: .modelConsensus,
                    name: "Multi-Model Consensus",
                    confidence: 0.95,
                    weight: 0.35,
                    details: "3/3 models agree",
                    verified: true
                ),
                ConfidenceSource(
                    type: .codeExecution,
                    name: "Code Execution",
                    confidence: 0.88,
                    weight: 0.25,
                    details: "All code blocks executed successfully",
                    verified: true
                )
            ],
            decomposition: ConfidenceDecomposition(
                factors: [
                    ConfidenceDecomposition.DecompositionFactor(
                        name: "Model Agreement",
                        contribution: 0.4,
                        explanation: "3/3 models agree"
                    )
                ],
                conflicts: [],
                reasoning: "High confidence based on strong model consensus and successful code execution.",
                suggestions: []
            )
        ))

        ConfidenceBadge(result: ConfidenceResult(
            overallConfidence: 0.65,
            sources: [
                ConfidenceSource(
                    type: .modelConsensus,
                    name: "Multi-Model Consensus",
                    confidence: 0.60,
                    weight: 0.35,
                    details: "2/3 models agree",
                    verified: false
                )
            ],
            decomposition: ConfidenceDecomposition(
                factors: [],
                conflicts: [
                    ConfidenceDecomposition.ConflictInfo(
                        source1: "Claude",
                        source2: "GPT-4",
                        description: "Different interpretations of the requirements",
                        severity: .moderate
                    )
                ],
                reasoning: "Medium confidence due to conflicting model opinions.",
                suggestions: ["Verify requirements manually", "Add more context"]
            )
        ))

        ConfidenceBadge(result: ConfidenceResult(
            overallConfidence: 0.35,
            sources: [],
            decomposition: ConfidenceDecomposition(
                factors: [],
                conflicts: [],
                reasoning: "Low confidence - insufficient verification sources.",
                suggestions: ["Enable web verification", "Run code execution"]
            )
        ))
    }
    .padding()
    .frame(width: 400)
}

#Preview("Confidence Gauge") {
    HStack(spacing: 30) {
        ConfidenceGauge(confidence: 0.92, size: 80)
        ConfidenceGauge(confidence: 0.65, size: 80)
        ConfidenceGauge(confidence: 0.35, size: 80)
    }
    .padding()
}
