import Foundation
@preconcurrency import SwiftData

// MARK: - Message Branching

extension ChatManager {

    /// Edit a user message and create a new branch — re-sends to AI
    func editMessageAndBranch(
        _ message: Message,
        newContent: String,
        in conversation: Conversation
    ) async throws {
        guard let context = chatModelContext else { throw ChatError.noModelContext }
        guard message.messageRole == .user else { return }

        // Count existing branches for this parent
        let parentId = message.parentMessageId ?? message.id
        let existingBranches = conversation.messages.filter {
            $0.parentMessageId == parentId || $0.id == parentId
        }
        let branchIndex = existingBranches.count

        // Create branched message
        let branchedMessage = message.createBranch(
            newContent: .text(newContent),
            branchIndex: branchIndex
        )
        conversation.messages.append(branchedMessage)
        context.insert(branchedMessage)

        // Delete assistant messages that followed the original in the same branch
        let messagesAfter = conversation.messages.filter {
            $0.orderIndex > message.orderIndex && $0.branchIndex == message.branchIndex
        }
        for msg in messagesAfter {
            context.delete(msg)
        }

        try context.save()

        // Re-send to get a new AI response for the branched message
        try await sendMessage(newContent, in: conversation)
    }

    /// Get all branches (sibling messages) for a given message
    func getBranches(for message: Message, in conversation: Conversation) -> [Message] {
        let parentId = message.parentMessageId ?? message.id
        return conversation.messages
            .filter { $0.id == parentId || $0.parentMessageId == parentId }
            .sorted { $0.branchIndex < $1.branchIndex }
    }

    /// Switch the visible branch for a message position
    func switchToBranch(
        _ branchIndex: Int,
        for message: Message,
        in conversation: Conversation
    ) -> Message? {
        let branches = getBranches(for: message, in: conversation)
        guard branchIndex >= 0, branchIndex < branches.count else { return nil }
        return branches[branchIndex]
    }
}
