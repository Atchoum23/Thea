//
//  AgentFeedbackSection.swift
//  Thea
//
//  Reusable feedback UI for agent sessions: thumbs up/down + comment field.
//  Used in TheaAgentDetailView (macOS) and IOSAgentDetailView (iOS).
//

import SwiftUI

struct AgentFeedbackSection: View {
    let session: TheaAgentSession
    @State private var feedbackComment: String = ""
    @State private var showCommentField = false

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            sectionTitle("Rate this result")

            if let rating = session.userRating {
                ratedView(rating: rating)
            } else {
                unratedView
            }
        }
    }

    // MARK: - Rated State

    private func ratedView(rating: AgentFeedbackRating) -> some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xs) {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: rating.sfSymbol)
                    .foregroundStyle(rating == .positive ? .green : .red)
                Text(rating == .positive ? "Helpful" : "Not helpful")
                    .font(.theaCaption1)
            }
            if let comment = session.userFeedbackComment, !comment.isEmpty {
                Text(comment)
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
                    .padding(TheaSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: TheaCornerRadius.sm)
                            .fill(Color.secondary.opacity(0.06))
                    )
            }
        }
    }

    // MARK: - Unrated State

    private var unratedView: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            HStack(spacing: TheaSpacing.md) {
                Button {
                    submitRating(.positive)
                } label: {
                    Label("Helpful", systemImage: "hand.thumbsup")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Rate as helpful")

                Button {
                    submitRating(.negative)
                } label: {
                    Label("Not helpful", systemImage: "hand.thumbsdown")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Rate as not helpful")

                Spacer()

                Button {
                    showCommentField.toggle()
                } label: {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a comment")
            }

            if showCommentField {
                HStack(spacing: TheaSpacing.sm) {
                    TextField("Optional feedback...", text: $feedbackComment)
                        .textFieldStyle(.roundedBorder)
                        .font(.theaCaption1)
                    #if os(macOS)
                        .frame(maxWidth: .infinity)
                    #endif
                }
            }
        }
    }

    // MARK: - Actions

    private func submitRating(_ rating: AgentFeedbackRating) {
        let comment = feedbackComment.isEmpty ? nil : feedbackComment
        TheaAgentOrchestrator.shared.submitFeedback(
            for: session, rating: rating, comment: comment
        )
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.theaSubhead)
            .foregroundStyle(.secondary)
    }
}
