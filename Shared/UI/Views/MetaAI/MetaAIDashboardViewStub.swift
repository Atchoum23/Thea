// MetaAIDashboardViewStub.swift
// Thea
//
// Stub for MetaAIDashboardView while full MetaAI backend is being restored.
// The full implementation is in MetaAIDashboardView.swift (excluded while
// MetaAICoordinator / THEASelfAwareness / WorkflowBuilder etc. are re-activated).

import SwiftUI

struct MetaAIDashboardView: View {
    var body: some View {
        VStack(spacing: TheaSpacing.xl) {
            Image(systemName: "brain.filled.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
            Text("Meta-AI Dashboard")
                .font(.theaTitle2)
            Text("Full MetaAI backend is being restored.\nCoordinator and workflow types coming soon.")
                .font(.theaBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Meta-AI")
    }
}
