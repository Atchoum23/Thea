// SquadsViewStub.swift
// Thea
//
// Stub for SquadsView while SquadOrchestrator / CommunicationStrategy / CoordinationMode
// types are being ported to active build targets.

import SwiftUI

struct SquadsView: View {
    var body: some View {
        VStack(spacing: TheaSpacing.xl) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Squads")
                .font(.theaTitle2)
            Text("Multi-agent squad coordination coming soon.\nSquadOrchestrator integration in progress.")
                .font(.theaBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Squads")
    }
}
