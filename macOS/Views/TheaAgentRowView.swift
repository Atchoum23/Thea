//
//  TheaAgentRowView.swift
//  Thea
//
//  Compact card for a single agent session in the sidebar.
//

import SwiftUI

#if os(macOS)
struct TheaAgentRowView: View {
    let session: TheaAgentSession
    var isSelected: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            stateIndicator
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.theaSubhead)
                    .lineLimit(1)
                Text(session.taskDescription)
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            trailingInfo
        }
        .padding(TheaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: TheaCornerRadius.md)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TheaCornerRadius.md)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    // MARK: - State Indicator

    private var stateIndicator: some View {
        Circle()
            .fill(stateColor)
            .frame(width: 8, height: 8)
            .overlay {
                if session.state == .working {
                    Circle()
                        .stroke(stateColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 14, height: 14)
                }
            }
    }

    private var stateColor: Color {
        switch session.state {
        case .idle: .gray
        case .planning: .orange
        case .working: .green
        case .awaitingApproval: .yellow
        case .paused: .yellow
        case .completed: .blue
        case .failed: .red
        case .cancelled: .gray
        }
    }

    // MARK: - Trailing Info

    @ViewBuilder
    private var trailingInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(elapsedText)
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            if isHovered && session.state.isActive {
                Button {
                    TheaAgentOrchestrator.shared.cancelSession(session)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel agent")
            } else if let progress = session.progress {
                ProgressView(value: progress)
                    .frame(width: 40)
            }
        }
    }

    private var elapsedText: String {
        let elapsed = session.elapsed
        if elapsed < 60 {
            return "\(Int(elapsed))s"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m"
        } else {
            return "\(Int(elapsed / 3600))h"
        }
    }
}
#endif
