// ChatEnhancementViews.swift
// Thea — W3: Chat Enhancement Feature Components
//
// ActionApprovalSheet (W3-5), ConsensusBreakdownView (W3-3)
// Note: AgentPhaseProgressBar lives in Shared/UI/Components/AgentPhaseProgressBar.swift
// Note: CloudSyncStatusView lives in Shared/UI/Components/CloudSyncStatusView.swift

import SwiftUI

// MARK: - W3-5: AutonomyController Action Approval Sheet

/// Rich approval sheet for pending autonomous actions.
/// Shows risk level, action details, reversibility warning, and decision buttons.
struct ActionApprovalSheet: View {
    let pendingAction: THEAPendingAction
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: TheaSpacing.lg) {
            // Risk level header
            HStack {
                Image(systemName: riskIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(pendingAction.action.riskLevel.color)
                VStack(alignment: .leading) {
                    Text("Action Approval Required")
                        .font(.theaHeadline)
                    Text("\(pendingAction.action.riskLevel.displayName) Risk")
                        .font(.theaCaption1)
                        .foregroundStyle(pendingAction.action.riskLevel.color)
                }
                Spacer()
            }

            Divider()

            // Action title + description
            VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                Text(pendingAction.action.title)
                    .font(.theaTitle3)
                Text(pendingAction.action.description)
                    .font(.theaBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Reason from autonomy system
            if !pendingAction.reason.isEmpty {
                GroupBox("Why Thea wants to do this") {
                    Text(pendingAction.reason)
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Category pill
            HStack {
                Label(pendingAction.action.category.rawValue.capitalized, systemImage: "tag")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                Spacer()
            }

            // Reversibility warning
            if pendingAction.action.rollback == nil {
                Label("This action cannot be undone", systemImage: "exclamationmark.triangle.fill")
                    .font(.theaCaption1)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Decision buttons
            HStack(spacing: TheaSpacing.md) {
                Button("Deny") {
                    AutonomyController.shared.rejectAction(pendingAction.id)
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                Button("Allow Once") {
                    Task { @MainActor in
                        await AutonomyController.shared.approveAction(pendingAction.id)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(TheaSpacing.xl)
        .frame(minWidth: 360, maxWidth: 480, minHeight: 300)
    }

    private var riskIcon: String {
        switch pendingAction.action.riskLevel {
        case .none, .minimal: return "checkmark.shield"
        case .low: return "shield"
        case .medium: return "shield.lefthalf.filled"
        case .high: return "shield.fill"
        case .critical: return "exclamationmark.shield.fill"
        }
    }
}

// MARK: - W3-3: Confidence / Consensus Breakdown View

/// Tappable confidence indicator that expands to show the full verification breakdown.
/// Wraps `ConfidenceBadge` with a synthesized `ConfidenceResult` from a scalar score.
struct ConsensusBreakdownView: View {
    let confidence: Double

    private var syntheticResult: ConfidenceResult {
        let source = ConfidenceSource(
            type: .modelConsensus,
            name: "Verification Pipeline",
            confidence: confidence,
            weight: 1.0,
            details: "\(Int(confidence * 100))% verified across sources",
            verified: confidence >= 0.6
        )
        let decomp = ConfidenceDecomposition(
            factors: [
                ConfidenceDecomposition.DecompositionFactor(
                    name: "Overall Score",
                    contribution: (confidence * 2) - 1.0,   // map [0,1] → [-1,+1]
                    explanation: confidence >= 0.85
                        ? "High confidence — multiple sources agree"
                        : confidence >= 0.6
                        ? "Moderate confidence — some uncertainty present"
                        : "Low confidence — sources diverge or unverified"
                )
            ],
            conflicts: [],
            reasoning: "Confidence score: \(Int(confidence * 100))%",
            suggestions: confidence < 0.6 ? ["Ask Thea to verify this answer", "Cross-check with another source"] : []
        )
        return ConfidenceResult(
            overallConfidence: confidence,
            sources: [source],
            decomposition: decomp
        )
    }

    var body: some View {
        ConfidenceBadge(result: syntheticResult)
    }
}
