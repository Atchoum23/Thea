// THEAThinkingView.swift
// Thea V2 - THEA Decision Visibility
//
// Shows THEA's thinking process and decision reasoning to the user.
// Makes the Meta-AI visible and transparent.
//
// Created: February 3, 2026

import SwiftUI

// MARK: - THEA Thinking View

/// Expandable view showing THEA's decision-making process
public struct THEAThinkingView: View {
    let decision: THEADecision

    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            headerView
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }

            // Expandable content
            if isExpanded {
                detailsView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TheaBrandColors.gold.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: TheaBrandColors.gold.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            // THEA spiral icon
            TheaSpiralIconView(size: 24, isThinking: false, showGlow: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("THEA's Thinking")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                // Quick summary
                Text(decision.reasoning.taskTypeDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Confidence indicator
            ConfidenceIndicator(confidence: decision.confidenceScore)

            // Expand chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Details

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 12)

            // Task Classification
            DetailRow(
                icon: "tag.fill",
                title: "Task Type",
                value: decision.reasoning.taskTypeDescription,
                detail: "\(Int(decision.reasoning.taskConfidence * 100))% confident"
            )

            // Model Selection
            DetailRow(
                icon: "cpu.fill",
                title: "Model",
                value: formatModelName(decision.selectedModel),
                detail: decision.reasoning.whyThisModel
            )

            // Strategy
            DetailRow(
                icon: "arrow.triangle.branch",
                title: "Strategy",
                value: formatStrategy(decision.strategy),
                detail: decision.reasoning.whyThisStrategy
            )

            // Context Factors (if any significant ones)
            if !decision.contextFactors.isEmpty {
                contextFactorsSection
            }

            // Alternatives considered
            if !decision.reasoning.alternativesConsidered.isEmpty {
                alternativesSection
            }
        }
        .padding(.bottom, 12)
    }

    private var contextFactorsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Context Factors")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(decision.contextFactors) { factor in
                        ContextFactorChip(factor: factor)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Alternatives Considered")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(decision.reasoning.alternativesConsidered.enumerated()), id: \.offset) { _, alt in
                    HStack(spacing: 4) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(formatModelName(alt.model))
                            .fontWeight(.medium)
                        Text("-")
                            .foregroundStyle(.secondary)
                        Text(alt.reason)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Helpers

    private var backgroundStyle: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color(white: 0.1).opacity(0.8))
            : AnyShapeStyle(Color(white: 0.95).opacity(0.9))
    }

    private func formatModelName(_ model: String) -> String {
        // Remove provider prefix for cleaner display
        if model.contains("/") {
            return String(model.split(separator: "/").last ?? Substring(model))
        }
        return model
    }

    private func formatStrategy(_ strategy: THEAExecutionStrategy) -> String {
        switch strategy {
        case .direct: return "Direct"
        case .decomposed: return "Decomposed"
        case .multiModel: return "Multi-Model"
        case .localFallback: return "Local"
        case .planMode: return "Plan Mode"
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Confidence Indicator

private struct ConfidenceIndicator: View {
    let confidence: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 6, height: 6)

            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(confidenceColor)
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

// MARK: - Context Factor Chip

private struct ContextFactorChip: View {
    let factor: ContextFactor

    var body: some View {
        HStack(spacing: 4) {
            influenceIcon
                .font(.system(size: 10))

            Text(factor.name)
                .font(.caption2)
                .fontWeight(.medium)

            Text(factor.value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipBackground)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var influenceIcon: some View {
        switch factor.influence {
        case .critical:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .high:
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.orange)
        case .medium:
            Image(systemName: "circle.fill")
                .foregroundStyle(.yellow)
        case .low:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private var chipBackground: Color {
        switch factor.influence {
        case .critical: return .red.opacity(0.15)
        case .high: return .orange.opacity(0.15)
        case .medium: return .yellow.opacity(0.15)
        case .low: return .green.opacity(0.15)
        }
    }
}

// MARK: - THEA Streaming Indicator with Decision

/// Shows THEA's thinking state during streaming with decision info
public struct THEAStreamingWithDecision: View {
    let decision: THEADecision?
    let isStreaming: Bool

    @State private var animationPhase = 0.0

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let decision {
                // Show compact decision info
                HStack(spacing: 8) {
                    // Animated THEA spiral icon
                    TheaSpiralIconView(size: 28, isThinking: isStreaming, showGlow: true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("THEA")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        if isStreaming {
                            Text("Generating with \(formatModelName(decision.selectedModel))...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(decision.reasoning.taskTypeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Confidence badge with golden styling
                    Text("\(Int(decision.confidenceScore * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(TheaBrandColors.deepNavy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(TheaBrandColors.spiralGradient)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if isStreaming {
                // Fallback: just show "THEA is thinking..."
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text("THEA is thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            animationPhase = 1.0
        }
    }

    private func formatModelName(_ model: String) -> String {
        if model.contains("/") {
            return String(model.split(separator: "/").last ?? Substring(model))
        }
        return model
    }
}

// MARK: - THEA Suggestions View

/// Shows proactive suggestions from THEA
public struct THEASuggestionsView: View {
    let suggestions: [THEASuggestion]
    var onSuggestionTap: ((THEASuggestion) -> Void)?

    public var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(TheaBrandColors.gold)

                    Text("THEA Suggests")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(TheaBrandColors.amber)
                }

                THEAFlowLayout(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        THEASuggestionChip(suggestion: suggestion) {
                            onSuggestionTap?(suggestion)
                        }
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [TheaBrandColors.gold.opacity(0.4), TheaBrandColors.amber.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}

private struct THEASuggestionChip: View {
    let suggestion: THEASuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconForType(suggestion.type))
                    .font(.caption2)

                Text(suggestion.title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TheaBrandColors.gold.opacity(0.15))
            .foregroundStyle(TheaBrandColors.gold)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(TheaBrandColors.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(suggestion.description)
    }

    private func iconForType(_ type: THEASuggestion.SuggestionType) -> String {
        switch type {
        case .action: return "play.circle.fill"
        case .followUp: return "arrow.right.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Simple Flow Layout for Suggestions

private struct THEAFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview("THEA Thinking View") {
    let sampleDecision = THEADecision(
        id: UUID(),
        reasoning: THEAReasoning(
            taskType: .codeGeneration,
            taskTypeDescription: "Code Generation",
            taskConfidence: 0.92,
            whyThisModel: "Selected claude-4-sonnet because: Code tasks require strong reasoning capabilities. Historical data shows good performance for similar queries.",
            whyThisStrategy: "Direct execution is most efficient for this query.",
            alternativesConsidered: [
                (model: "gpt-4o", reason: "Would be better for math-heavy code")
            ],
            classificationMethod: .ai
        ),
        selectedModel: "anthropic/claude-4-sonnet",
        selectedProvider: "anthropic",
        strategy: .direct,
        confidenceScore: 0.92,
        contextFactors: [
            ContextFactor(name: "Battery", value: "87%", influence: .low, description: "Battery OK"),
            ContextFactor(name: "Network", value: "WiFi", influence: .low, description: "Network available"),
            ContextFactor(name: "Time", value: "Work hours", influence: .medium, description: "Optimizing for productivity")
        ],
        timestamp: Date()
    )

    VStack(spacing: 20) {
        THEAThinkingView(decision: sampleDecision)
            .padding()

        THEAStreamingWithDecision(decision: sampleDecision, isStreaming: true)
            .padding()

        THEASuggestionsView(suggestions: [
            THEASuggestion(type: .action, title: "Run this code?", description: "I can help you test this code", action: "run_code"),
            THEASuggestion(type: .followUp, title: "Add tests?", description: "Would you like unit tests?", action: "generate_tests")
        ])
        .padding()
    }
    .frame(width: 400)
    #if os(macOS)
    .background(Color(nsColor: .windowBackgroundColor))
    #else
    .background(Color(uiColor: .systemBackground))
    #endif
}
