# Nexus - Comprehensive Feature Enhancement Roadmap
## Detailed Technical Specifications & Implementation Guide

**Version:** 2.0
**Date:** November 18, 2025
**Status:** Strategic Planning Document
**Project:** Nexus AI Suite
**Repository:** https://github.com/Atchoum23/Nexus

---

## Document Overview

This comprehensive technical roadmap transforms Nexus from an excellent macOS AI assistant into a best-in-class AI orchestration platform. The document provides detailed technical specifications, implementation guides, API designs, data models, UI mockups, testing strategies, and migration plans for each feature.

**Current Foundation:**
- 119 Swift files (~35,000 LOC)
- 3-tier architecture (Nexus App → NexusUI → NexusCore)
- 15 MCP server integrations
- Advanced AI routing (93-97% cost savings)
- Hierarchical memory system with CloudKit sync

**Strategic Goals:**
- 🎯 Transform from tool to intelligent partner
- 🎯 Add multimodal capabilities (vision, voice, documents)
- 🎯 Enable team collaboration
- 🎯 Expand to iOS, Web, CLI
- 🎯 Add enterprise security and compliance

---

## Table of Contents

1. [Phase 1: Quick Wins (1-2 Months)](#phase-1-quick-wins)
   - 1.1 [Conversation Branching & Forking](#11-conversation-branching--forking)
   - 1.2 [Semantic Memory Search](#12-semantic-memory-search)
   - 1.3 [Conversation Templates](#13-conversation-templates)
   - 1.4 [Cost Budget Management](#14-cost-budget-management)
   - 1.5 [Enhanced Dashboard](#15-enhanced-dashboard)

2. [Phase 2: Core Enhancements (3-4 Months)](#phase-2-core-enhancements)
   - 2.1 [Vision & Image Analysis](#21-vision--image-analysis)
   - 2.2 [Advanced Voice Capabilities](#22-advanced-voice-capabilities)
   - 2.3 [Knowledge Graph Enhancements](#23-knowledge-graph-enhancements)
   - 2.4 [Workflow Automation Engine](#24-workflow-automation-engine)
   - 2.5 [Plugin System Foundation](#25-plugin-system-foundation)

3. [Phase 3: Platform Expansion (4-6 Months)](#phase-3-platform-expansion)
   - 3.1 [iOS Companion App](#31-ios-companion-app)
   - 3.2 [Collaboration Features](#32-collaboration-features)
   - 3.3 [Developer Integrations](#33-developer-integrations)
   - 3.4 [Advanced Context System](#34-advanced-context-system)
   - 3.5 [Security & Compliance](#35-security--compliance)

4. [Phase 4: Advanced Features (6+ Months)](#phase-4-advanced-features)
   - 4.1 [Learning Platform](#41-learning-platform)
   - 4.2 [Web Interface](#42-web-interface)
   - 4.3 [CLI Tool](#43-cli-tool)
   - 4.4 [Advanced Analytics](#44-advanced-analytics)
   - 4.5 [Enterprise Features](#45-enterprise-features)

5. [Cross-Cutting Concerns](#cross-cutting-concerns)
6. [Implementation Guidelines](#implementation-guidelines)
7. [Appendices](#appendices)

---

# Phase 1: Quick Wins (1-2 Months)

**Timeline:** Weeks 1-8  
**Team Size:** 2-3 developers  
**Budget:** $30K-50K  
**Goal:** High-impact features with relatively low implementation complexity  
**Status:** ✅ **COMPLETE** - All Phase 1 features implemented November 18, 2025

---

## 1.1 Conversation Branching & Forking

**Status:** ✅ **IMPLEMENTED** - November 18, 2025

### Executive Summary

**Business Value:**
- **Problem:** Users lose context when exploring alternatives
- **Solution:** Branch conversations at any point to explore different approaches
- **Impact:** 40% reduction in context repetition, better decision-making

**Implementation Effort:** 2 weeks
**Priority:** HIGH
**Dependencies:** None
**Risk Level:** LOW

### User Stories

```gherkin
Feature: Conversation Branching
  As a user
  I want to branch conversations at any point
  So that I can explore alternatives without losing original context

Scenario: Creating a branch from existing message
  Given I have a conversation with 10 messages
  When I right-click message #5 and select "Create Branch"
  And I enter branch title "Alternative approach"
  Then a new conversation is created with messages 1-5 copied
  And I am switched to the new branched conversation
  And the original conversation is marked as "parent"

Scenario: Viewing branch tree
  Given I have a conversation with 3 branches
  When I click "View Branches" button
  Then I see a tree visualization showing all branches
  And I can click any branch to switch to it

Scenario: Merging branch back to parent
  Given I have a branch with 5 new messages
  When I select "Merge to Parent"
  And I choose merge strategy "Append"
  Then the new messages are added to the parent conversation
  And the branch is marked as merged
```

### Technical Architecture

#### Data Model Extensions

```swift
// MARK: - Core Data Schema Changes

extension Conversation {
    // Add to existing Conversation entity via Core Data model editor
    // or programmatic model in PersistenceController

    @NSManaged public var parentConversation: Conversation?
    @NSManaged public var branches: NSSet?  // Set<Conversation>
    @NSManaged public var branchPoint: Message?
    @NSManaged public var branchTitle: String?
    @NSManaged public var divergedAt: Date?
    @NSManaged public var isMerged: Bool
    @NSManaged public var mergedAt: Date?
}

// MARK: - Swift Structs

public struct ConversationBranch: Identifiable, Codable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let parentConversationID: UUID
    public let branchPoint: MessageReference
    public let title: String
    public let createdAt: Date
    public let messageCount: Int
    public let totalCost: Decimal
    public let isMerged: Bool

    public struct MessageReference: Codable, Sendable {
        let messageID: UUID
        let content: String  // First 100 chars
        let timestamp: Date
        let index: Int  // Position in conversation
    }
}

public struct BranchTree: Codable, Sendable {
    public let root: ConversationNode
    public let totalBranches: Int
    public let maxDepth: Int
    public let createdAt: Date

    public struct ConversationNode: Identifiable, Codable, Sendable {
        public let id: UUID
        public let conversation: ConversationInfo
        public let branches: [ConversationNode]
        public let depth: Int
        public let branchPointIndex: Int?

        public struct ConversationInfo: Codable, Sendable {
            let id: UUID
            let title: String
            let messageCount: Int
            let createdAt: Date
            let updatedAt: Date
            let totalCost: Decimal
            let isMerged: Bool
        }
    }
}
```

#### Core API Implementation

```swift
// MARK: - File: Sources/NexusCore/ConversationBranchManager.swift

import CoreData
import Foundation

@MainActor
public final class ConversationBranchManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = ConversationBranchManager()

    // MARK: - Published Properties
    @Published public private(set) var branchTree: BranchTree?
    @Published public private(set) var isBuilding: Bool = false
    @Published public private(set) var error: BranchError?

    // MARK: - Dependencies
    private let conversationManager: ConversationManager
    private let persistenceController: PersistenceController
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Initialization
    private init() {
        self.conversationManager = ConversationManager.shared
        self.persistenceController = PersistenceController.shared
    }

    // MARK: - Branch Creation

    /// Create a new branch from a specific message
    /// - Parameters:
    ///   - message: The message to branch from
    ///   - title: Title for the new branch
    ///   - copyStrategy: How to handle message copying
    /// - Returns: Newly created branched conversation
    public func createBranch(
        from message: Message,
        title: String,
        copyStrategy: BranchCopyStrategy = .includeAllPrevious
    ) async throws -> Conversation {
        guard let parentConversation = message.conversation else {
            throw BranchError.invalidParent
        }

        // Validate title
        let branchTitle = title.isEmpty
            ? "Branch: \(Date().formatted(date: .abbreviated, time: .shortened))"
            : title

        // Create new conversation
        let context = persistenceController.viewContext
        let branchedConversation = Conversation(context: context)
        branchedConversation.id = UUID()
        branchedConversation.title = branchTitle
        branchedConversation.createdAt = Date()
        branchedConversation.updatedAt = Date()

        // Set branch metadata
        branchedConversation.parentConversation = parentConversation
        branchedConversation.branchPoint = message
        branchedConversation.divergedAt = Date()
        branchedConversation.branchTitle = branchTitle
        branchedConversation.isMerged = false

        // Copy messages based on strategy
        switch copyStrategy {
        case .includeAllPrevious:
            try await copyMessagesBefore(message: message, to: branchedConversation)

        case .includeContext(let count):
            try await copyContextMessages(
                before: message,
                count: count,
                to: branchedConversation
            )

        case .startFresh:
            // No messages copied
            break
        }

        // Update parent's branch set
        var branches = parentConversation.branches as? Set<Conversation> ?? []
        branches.insert(branchedConversation)
        parentConversation.branches = branches as NSSet

        // Save context
        try context.save()

        // Reload conversations
        conversationManager.loadConversations()

        // Update branch tree
        await buildBranchTree(for: getRootConversation(parentConversation))

        return branchedConversation
    }

    // MARK: - Branch Navigation

    /// Get all branches for a conversation
    public func listBranches(for conversation: Conversation) -> [ConversationBranch] {
        guard let branches = conversation.branches as? Set<Conversation> else {
            return []
        }

        return branches.compactMap { branch -> ConversationBranch? in
            guard let branchID = branch.id,
                  let conversationID = conversation.id,
                  let branchPoint = branch.branchPoint,
                  let branchPointID = branchPoint.id else {
                return nil
            }

            let branchPointIndex = conversation.messagesArray.firstIndex(of: branchPoint) ?? 0

            return ConversationBranch(
                id: branchID,
                conversationID: branchID,
                parentConversationID: conversationID,
                branchPoint: ConversationBranch.MessageReference(
                    messageID: branchPointID,
                    content: String((branchPoint.content ?? "").prefix(100)),
                    timestamp: branchPoint.timestamp ?? Date(),
                    index: branchPointIndex
                ),
                title: branch.branchTitle ?? "Untitled Branch",
                createdAt: branch.divergedAt ?? Date(),
                messageCount: branch.messagesArray.count,
                totalCost: Decimal(branch.totalCost),
                isMerged: branch.isMerged
            )
        }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Build complete branch tree from root conversation
    public func buildBranchTree(for conversation: Conversation) async {
        isBuilding = true
        defer { isBuilding = false }

        let root = getRootConversation(conversation)
        let treeNode = buildNode(for: root, depth: 0)

        let maxDepth = calculateMaxDepth(node: treeNode)
        let totalBranches = countBranches(node: treeNode)

        branchTree = BranchTree(
            root: treeNode,
            totalBranches: totalBranches,
            maxDepth: maxDepth,
            createdAt: Date()
        )
    }

    // MARK: - Branch Merging

    /// Merge a branch back into parent
    public func mergeBranch(
        _ branch: Conversation,
        strategy: MergeStrategy = .appendToParent
    ) async throws {
        guard let parent = branch.parentConversation,
              let branchPoint = branch.branchPoint else {
            throw BranchError.cannotMergeRoot
        }

        let context = persistenceController.viewContext

        switch strategy {
        case .appendToParent:
            // Add all branch messages after branch point to parent
            let branchMessages = branch.messagesArray
            let branchPointIndex = branchMessages.firstIndex(of: branchPoint) ?? 0
            let newMessages = Array(branchMessages.dropFirst(branchPointIndex + 1))

            for message in newMessages {
                let newMessage = Message(context: context)
                newMessage.id = UUID()
                newMessage.content = message.content
                newMessage.role = message.role
                newMessage.timestamp = Date()
                newMessage.conversation = parent
                newMessage.modelUsed = message.modelUsed

                var messages = parent.messages as? Set<Message> ?? []
                messages.insert(newMessage)
                parent.messages = messages as NSSet
            }

        case .replaceFromBranchPoint:
            // Delete parent messages after branch point
            try deleteMessagesAfter(branchPoint, in: parent)

            // Add all branch messages
            let branchMessages = branch.messagesArray
            for message in branchMessages {
                let newMessage = Message(context: context)
                newMessage.id = UUID()
                newMessage.content = message.content
                newMessage.role = message.role
                newMessage.timestamp = Date()
                newMessage.conversation = parent

                var messages = parent.messages as? Set<Message> ?? []
                messages.insert(newMessage)
                parent.messages = messages as NSSet
            }

        case .createMergeCommit:
            // Add merge message
            let mergeMessage = Message(context: context)
            mergeMessage.id = UUID()
            mergeMessage.role = "system"
            mergeMessage.timestamp = Date()
            mergeMessage.conversation = parent
            mergeMessage.content = """
            [Merged branch: \(branch.branchTitle ?? "Untitled")]

            Branch created: \(branch.divergedAt?.formatted() ?? "Unknown")
            Messages in branch: \(branch.messagesArray.count)

            Branch exploration complete.
            """

            var messages = parent.messages as? Set<Message> ?? []
            messages.insert(mergeMessage)
            parent.messages = messages as NSSet
        }

        // Mark branch as merged
        branch.isMerged = true
        branch.mergedAt = Date()

        // Update parent
        parent.updatedAt = Date()

        // Save
        try context.save()

        // Reload
        conversationManager.loadConversations()
    }

    /// Delete a branch
    public func deleteBranch(_ branch: Conversation) async throws {
        guard branch.parentConversation != nil else {
            throw BranchError.cannotDeleteRoot
        }

        // Remove from parent
        if let parent = branch.parentConversation {
            var branches = parent.branches as? Set<Conversation> ?? []
            branches.remove(branch)
            parent.branches = branches as NSSet
        }

        // Delete conversation
        try conversationManager.deleteConversation(branch)
    }

    // MARK: - Private Helpers

    private func getRootConversation(_ conversation: Conversation) -> Conversation {
        var current = conversation
        while let parent = current.parentConversation {
            current = parent
        }
        return current
    }

    private func buildNode(
        for conversation: Conversation,
        depth: Int
    ) -> BranchTree.ConversationNode {
        let branches = (conversation.branches as? Set<Conversation>) ?? []
        let childNodes = branches.map { buildNode(for: $0, depth: depth + 1) }

        let branchPointIndex = conversation.branchPoint.flatMap { msg in
            conversation.messagesArray.firstIndex(of: msg)
        }

        let info = BranchTree.ConversationNode.ConversationInfo(
            id: conversation.id ?? UUID(),
            title: conversation.title ?? "Untitled",
            messageCount: conversation.messagesArray.count,
            createdAt: conversation.createdAt ?? Date(),
            updatedAt: conversation.updatedAt ?? Date(),
            totalCost: Decimal(conversation.totalCost),
            isMerged: conversation.isMerged
        )

        return BranchTree.ConversationNode(
            id: conversation.id ?? UUID(),
            conversation: info,
            branches: childNodes.sorted { $0.conversation.createdAt > $1.conversation.createdAt },
            depth: depth,
            branchPointIndex: branchPointIndex
        )
    }

    private func calculateMaxDepth(node: BranchTree.ConversationNode) -> Int {
        if node.branches.isEmpty {
            return node.depth
        }
        return node.branches.map { calculateMaxDepth(node: $0) }.max() ?? node.depth
    }

    private func countBranches(node: BranchTree.ConversationNode) -> Int {
        return node.branches.count + node.branches.reduce(0) { $0 + countBranches(node: $1) }
    }

    private func copyMessagesBefore(
        message: Message,
        to conversation: Conversation
    ) async throws {
        guard let sourceMessages = message.conversation?.messagesArray else {
            return
        }

        guard let branchIndex = sourceMessages.firstIndex(of: message) else {
            return
        }

        let context = persistenceController.viewContext
        let messagesToCopy = Array(sourceMessages[0...branchIndex])

        for sourceMessage in messagesToCopy {
            let newMessage = Message(context: context)
            newMessage.id = UUID()
            newMessage.content = sourceMessage.content
            newMessage.role = sourceMessage.role
            newMessage.timestamp = sourceMessage.timestamp
            newMessage.conversation = conversation
            newMessage.modelUsed = sourceMessage.modelUsed

            var messages = conversation.messages as? Set<Message> ?? []
            messages.insert(newMessage)
            conversation.messages = messages as NSSet
        }
    }

    private func copyContextMessages(
        before message: Message,
        count: Int,
        to conversation: Conversation
    ) async throws {
        guard let sourceMessages = message.conversation?.messagesArray else {
            return
        }

        guard let branchIndex = sourceMessages.firstIndex(of: message) else {
            return
        }

        let startIndex = max(0, branchIndex - count + 1)
        let messagesToCopy = Array(sourceMessages[startIndex...branchIndex])

        let context = persistenceController.viewContext

        for sourceMessage in messagesToCopy {
            let newMessage = Message(context: context)
            newMessage.id = UUID()
            newMessage.content = sourceMessage.content
            newMessage.role = sourceMessage.role
            newMessage.timestamp = sourceMessage.timestamp
            newMessage.conversation = conversation
            newMessage.modelUsed = sourceMessage.modelUsed

            var messages = conversation.messages as? Set<Message> ?? []
            messages.insert(newMessage)
            conversation.messages = messages as NSSet
        }
    }

    private func deleteMessagesAfter(
        _ message: Message,
        in conversation: Conversation
    ) throws {
        let messages = conversation.messagesArray
        guard let index = messages.firstIndex(of: message) else {
            return
        }

        let context = persistenceController.viewContext
        let messagesToDelete = Array(messages.dropFirst(index + 1))

        for msg in messagesToDelete {
            context.delete(msg)
        }
    }
}

// MARK: - Supporting Types

public enum BranchCopyStrategy: Codable, Sendable {
    case includeAllPrevious
    case includeContext(messageCount: Int)
    case startFresh
}

public enum MergeStrategy: Codable, Sendable {
    case appendToParent
    case replaceFromBranchPoint
    case createMergeCommit
}

public enum BranchError: LocalizedError {
    case invalidParent
    case cannotMergeRoot
    case cannotDeleteRoot
    case branchPointNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidParent:
            return "Cannot branch from a conversation without a valid parent"
        case .cannotMergeRoot:
            return "Cannot merge root conversation"
        case .cannotDeleteRoot:
            return "Cannot delete root conversation"
        case .branchPointNotFound:
            return "Branch point message not found"
        }
    }
}
```

#### UI Components

```swift
// MARK: - File: Sources/NexusUI/BranchCreationSheet.swift

import SwiftUI

struct BranchCreationSheet: View {
    @Binding var isPresented: Bool
    let message: Message

    @State private var branchTitle: String = ""
    @State private var copyStrategy: BranchCopyStrategy = .includeAllPrevious
    @State private var isCreating: Bool = false
    @State private var error: BranchError?

    @StateObject private var branchManager = ConversationBranchManager.shared
    @StateObject private var conversationManager = ConversationManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Branch")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Explore alternative approaches without losing context")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Branch point preview
            VStack(alignment: .leading, spacing: 8) {
                Label("Branching from:", systemImage: "arrow.triangle.branch")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role == "user" ? "You" : "AI")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(message.content ?? "")
                            .lineLimit(3)
                            .font(.body)
                    }

                    Spacer()

                    if let timestamp = message.timestamp {
                        Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }

            // Branch configuration
            VStack(alignment: .leading, spacing: 16) {
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Label("Branch Title", systemImage: "textformat")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("e.g., Alternative approach", text: $branchTitle)
                        .textFieldStyle(.roundedBorder)
                }

                // Copy strategy
                VStack(alignment: .leading, spacing: 8) {
                    Label("Include Messages", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Copy Strategy", selection: $copyStrategy) {
                        Text("All previous").tag(BranchCopyStrategy.includeAllPrevious)
                        Text("Last 5 only").tag(BranchCopyStrategy.includeContext(messageCount: 5))
                        Text("Start fresh").tag(BranchCopyStrategy.startFresh)
                    }
                    .pickerStyle(.segmented)

                    // Preview text
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)

                        Text(previewText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Error display
            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.orange)

                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    createBranch()
                } label: {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Create Branch")
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isCreating || branchTitle.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520, height: 480)
    }

    private var previewText: String {
        guard let conversation = message.conversation else {
            return "No conversation found"
        }

        let messages = conversation.messagesArray
        let branchIndex = messages.firstIndex(of: message) ?? 0

        switch copyStrategy {
        case .includeAllPrevious:
            return "Will copy \(branchIndex + 1) messages to new branch"
        case .includeContext(let count):
            let copyCount = min(count, branchIndex + 1)
            return "Will copy the last \(copyCount) messages to new branch"
        case .startFresh:
            return "New branch will start empty"
        }
    }

    private func createBranch() {
        isCreating = true
        error = nil

        Task {
            do {
                let branch = try await branchManager.createBranch(
                    from: message,
                    title: branchTitle,
                    copyStrategy: copyStrategy
                )

                // Switch to new branch
                await MainActor.run {
                    conversationManager.setActiveConversation(branch)
                    isPresented = false
                }
            } catch let branchError as BranchError {
                await MainActor.run {
                    error = branchError
                    isCreating = false
                }
            } catch {
                print("Unexpected error: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Branch Tree View

struct BranchTreeView: View {
    let rootConversation: Conversation

    @StateObject private var branchManager = ConversationBranchManager.shared
    @StateObject private var conversationManager = ConversationManager.shared
    @State private var selectedNodeID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Label("Branch Tree", systemImage: "network")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    if let tree = branchManager.branchTree {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(tree.totalBranches) branches")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Max depth: \(tree.maxDepth)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()
            }
            .padding()

            // Tree visualization
            if branchManager.isBuilding {
                ProgressView("Building branch tree...")
                    .padding()
            } else if let tree = branchManager.branchTree {
                ScrollView([.horizontal, .vertical]) {
                    ConversationNodeView(
                        node: tree.root,
                        selectedNodeID: $selectedNodeID,
                        isRoot: true,
                        onSelect: { conversation in
                            conversationManager.setActiveConversation(conversation)
                        }
                    )
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Branch Tree",
                    systemImage: "network.slash",
                    description: Text("This conversation has no branches yet")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await branchManager.buildBranchTree(for: rootConversation)
        }
    }
}

struct ConversationNodeView: View {
    let node: BranchTree.ConversationNode
    @Binding var selectedNodeID: UUID?
    let isRoot: Bool
    let onSelect: (Conversation) -> Void

    @StateObject private var conversationManager = ConversationManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            // Current node card
            VStack(spacing: 8) {
                Button {
                    selectedNodeID = node.id
                    if let conversation = conversationManager.conversations.first(where: { $0.id == node.id }) {
                        onSelect(conversation)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Image(systemName: isRoot ? "circle.fill" : "arrow.triangle.branch")
                                .foregroundColor(isRoot ? .blue : .purple)

                            Text(node.conversation.title)
                                .font(.headline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }

                        // Stats
                        VStack(spacing: 6) {
                            HStack {
                                Label("\(node.conversation.messageCount)", systemImage: "message")
                                    .font(.caption)

                                Spacer()

                                Text("$\(node.conversation.totalCost.formatted(.number.precision(.fractionLength(2))))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let branchPointIndex = node.branchPointIndex {
                                HStack {
                                    Text("Branched from message #\(branchPointIndex + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }
                            }

                            if node.conversation.isMerged {
                                HStack {
                                    Label("Merged", systemImage: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)

                                    Spacer()
                                }
                            }
                        }

                        // Date
                        Text(node.conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(width: 220)
                    .background(
                        selectedNodeID == node.id
                            ? Color.blue.opacity(0.15)
                            : Color.secondary.opacity(0.08)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedNodeID == node.id ? Color.blue : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)

                // Connector to children
                if !node.branches.isEmpty {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }

            // Child branches
            if !node.branches.isEmpty {
                VStack(alignment: .leading, spacing: 30) {
                    ForEach(node.branches) { childNode in
                        HStack(spacing: 0) {
                            // Horizontal connector
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 30, height: 2)

                            // Recursive child
                            ConversationNodeView(
                                node: childNode,
                                selectedNodeID: $selectedNodeID,
                                isRoot: false,
                                onSelect: onSelect
                            )
                        }
                    }
                }
            }
        }
    }
}
```

### Integration Points

```swift
// MARK: - ChatView Integration

extension ChatView {
    var enhancedMessageContextMenu: some View {
        ForEach(messages.indices, id: \.self) { index in
            let message = messages[index]

            ContextMenu {
                // Existing menu items...

                Divider()

                // Branch creation
                Button {
                    selectedMessage = message
                    showBranchSheet = true
                } label: {
                    Label("Create Branch from Here", systemImage: "arrow.triangle.branch")
                }
                .disabled(message.conversation == nil)

                // View branch tree (if conversation has parent or branches)
                if hasParentOrBranches(message.conversation) {
                    Button {
                        showBranchTreeView = true
                    } label: {
                        Label("View Branch Tree", systemImage: "network")
                    }
                }
            }
        }
    }

    private func hasParentOrBranches(_ conversation: Conversation?) -> Bool {
        guard let conv = conversation else { return false }
        return conv.parentConversation != nil || (conv.branches?.count ?? 0) > 0
    }
}

// MARK: - ConversationListView Integration

extension ConversationListView {
    var conversationRowWithBranchIndicators: some View {
        ForEach(conversations) { conversation in
            HStack(spacing: 12) {
                // Existing row content...

                // Branch indicators
                HStack(spacing: 6) {
                    if let branchCount = (conversation.branches as? Set<Conversation>)?.count,
                       branchCount > 0 {
                        Label("\(branchCount)", systemImage: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .help("\(branchCount) \(branchCount == 1 ? "branch" : "branches")")
                    }

                    if conversation.parentConversation != nil {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .help("Branched conversation")
                    }

                    if conversation.isMerged {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .help("Merged branch")
                    }
                }
            }
        }
    }
}
```

### Testing Strategy

```swift
// MARK: - File: Tests/NexusTests/ConversationBranchManagerTests.swift

import XCTest
@testable import NexusCore

@MainActor
final class ConversationBranchManagerTests: XCTestCase {
    var branchManager: ConversationBranchManager!
    var conversationManager: ConversationManager!
    var testConversation: Conversation!
    var testMessages: [Message]!

    override func setUp() async throws {
        branchManager = ConversationBranchManager.shared
        conversationManager = ConversationManager.shared

        // Create test conversation
        testConversation = conversationManager.createConversation(title: "Test Conversation")

        // Add 10 test messages
        testMessages = []
        for i in 0..<10 {
            let message = conversationManager.addMessage(
                to: testConversation,
                content: "Test message \(i)",
                role: i % 2 == 0 ? "user" : "assistant"
            )
            testMessages.append(message)
        }
    }

    override func tearDown() async throws {
        if let conversation = testConversation {
            try? conversationManager.deleteConversation(conversation)
        }
    }

    // MARK: - Branch Creation Tests

    func testCreateBranchWithAllPreviousMessages() async throws {
        // Given: Message at index 5
        let branchPoint = testMessages[5]

        // When: Create branch
        let branch = try await branchManager.createBranch(
            from: branchPoint,
            title: "Test Branch",
            copyStrategy: .includeAllPrevious
        )

        // Then: Branch should have 6 messages (0-5 inclusive)
        XCTAssertEqual(branch.messagesArray.count, 6, "Branch should contain all previous messages")
        XCTAssertEqual(branch.parentConversation, testConversation)
        XCTAssertEqual(branch.branchPoint, branchPoint)
        XCTAssertEqual(branch.branchTitle, "Test Branch")
        XCTAssertFalse(branch.isMerged)
    }

    func testCreateBranchWithContextMessages() async throws {
        // Given: Message at index 7
        let branchPoint = testMessages[7]

        // When: Create branch with last 3 messages
        let branch = try await branchManager.createBranch(
            from: branchPoint,
            title: "Context Branch",
            copyStrategy: .includeContext(messageCount: 3)
        )

        // Then: Should have 3 messages
        XCTAssertEqual(branch.messagesArray.count, 3, "Should have 3 context messages")

        // Verify correct messages were copied (indices 5, 6, 7)
        let branchContent = branch.messagesArray.compactMap { $0.content }
        XCTAssertTrue(branchContent.contains("Test message 5"))
        XCTAssertTrue(branchContent.contains("Test message 6"))
        XCTAssertTrue(branchContent.contains("Test message 7"))
    }

    func testCreateBranchStartFresh() async throws {
        // Given: Any message
        let branchPoint = testMessages[3]

        // When: Create branch with startFresh
        let branch = try await branchManager.createBranch(
            from: branchPoint,
            title: "Fresh Branch",
            copyStrategy: .startFresh
        )

        // Then: Should have no messages
        XCTAssertEqual(branch.messagesArray.count, 0, "Fresh branch should have no messages")
    }

    // MARK: - Branch Tree Tests

    func testBuildBranchTree() async throws {
        // Given: Create 2 branches
        let branch1 = try await branchManager.createBranch(
            from: testMessages[3],
            title: "Branch 1",
            copyStrategy: .includeAllPrevious
        )

        let branch2 = try await branchManager.createBranch(
            from: testMessages[7],
            title: "Branch 2",
            copyStrategy: .includeAllPrevious
        )

        // When: Build tree
        await branchManager.buildBranchTree(for: testConversation)

        // Then: Tree should be correct
        XCTAssertNotNil(branchManager.branchTree)
        XCTAssertEqual(branchManager.branchTree?.totalBranches, 2)
        XCTAssertEqual(branchManager.branchTree?.root.branches.count, 2)
        XCTAssertEqual(branchManager.branchTree?.root.conversation.id, testConversation.id)
    }

    func testNestedBranching() async throws {
        // Given: Create branch, then branch from that branch
        let firstBranch = try await branchManager.createBranch(
            from: testMessages[5],
            title: "First Branch",
            copyStrategy: .includeAllPrevious
        )

        // Add message to first branch
        let newMessage = conversationManager.addMessage(
            to: firstBranch,
            content: "New message in branch",
            role: "user"
        )

        // Create nested branch
        let nestedBranch = try await branchManager.createBranch(
            from: newMessage,
            title: "Nested Branch",
            copyStrategy: .includeAllPrevious
        )

        // When: Build tree
        await branchManager.buildBranchTree(for: testConversation)

        // Then: Tree should show nested structure
        XCTAssertEqual(branchManager.branchTree?.maxDepth, 2)
        XCTAssertEqual(branchManager.branchTree?.totalBranches, 2)

        // First branch should have one child
        let firstBranchNode = branchManager.branchTree?.root.branches.first { $0.id == firstBranch.id }
        XCTAssertEqual(firstBranchNode?.branches.count, 1)
    }

    // MARK: - Branch Merging Tests

    func testMergeBranchAppendStrategy() async throws {
        // Given: Create branch and add new messages
        let branch = try await branchManager.createBranch(
            from: testMessages[5],
            title: "Merge Test",
            copyStrategy: .includeAllPrevious
        )

        conversationManager.addMessage(to: branch, content: "Branch message 1", role: "user")
        conversationManager.addMessage(to: branch, content: "Branch message 2", role: "assistant")

        let originalCount = testConversation.messagesArray.count

        // When: Merge
        try await branchManager.mergeBranch(branch, strategy: .appendToParent)

        // Then: Parent should have new messages
        XCTAssertEqual(
            testConversation.messagesArray.count,
            originalCount + 2,
            "Parent should have 2 additional messages"
        )
        XCTAssertTrue(branch.isMerged, "Branch should be marked as merged")
        XCTAssertNotNil(branch.mergedAt, "Merge timestamp should be set")
    }

    func testMergeBranchCreateMergeCommit() async throws {
        // Given: Branch with new messages
        let branch = try await branchManager.createBranch(
            from: testMessages[3],
            title: "Commit Merge Test",
            copyStrategy: .includeAllPrevious
        )

        conversationManager.addMessage(to: branch, content: "Branch exploration", role: "user")

        let originalCount = testConversation.messagesArray.count

        // When: Merge with commit strategy
        try await branchManager.mergeBranch(branch, strategy: .createMergeCommit)

        // Then: Should have merge commit message
        XCTAssertEqual(testConversation.messagesArray.count, originalCount + 1)

        let lastMessage = testConversation.messagesArray.last
        XCTAssertEqual(lastMessage?.role, "system")
        XCTAssertTrue(lastMessage?.content?.contains("Merged branch") ?? false)
    }

    // MARK: - Branch Listing Tests

    func testListBranches() async throws {
        // Given: Create 3 branches
        _ = try await branchManager.createBranch(
            from: testMessages[2],
            title: "Branch A",
            copyStrategy: .includeAllPrevious
        )

        _ = try await branchManager.createBranch(
            from: testMessages[5],
            title: "Branch B",
            copyStrategy: .includeAllPrevious
        )

        _ = try await branchManager.createBranch(
            from: testMessages[8],
            title: "Branch C",
            copyStrategy: .includeAllPrevious
        )

        // When: List branches
        let branches = branchManager.listBranches(for: testConversation)

        // Then: Should return all 3 branches
        XCTAssertEqual(branches.count, 3)

        // Should be sorted by created date (newest first)
        XCTAssertTrue(branches[0].createdAt >= branches[1].createdAt)
        XCTAssertTrue(branches[1].createdAt >= branches[2].createdAt)
    }

    // MARK: - Error Handling Tests

    func testCannotMergeRootConversation() async throws {
        // Given: Root conversation
        let root = testConversation!

        // When/Then: Should throw error
        do {
            try await branchManager.mergeBranch(root, strategy: .appendToParent)
            XCTFail("Should throw cannotMergeRoot error")
        } catch let error as BranchError {
            XCTAssertEqual(error, .cannotMergeRoot)
        }
    }

    func testCannotDeleteRootConversation() async throws {
        // Given: Root conversation
        let root = testConversation!

        // When/Then: Should throw error
        do {
            try await branchManager.deleteBranch(root)
            XCTFail("Should throw cannotDeleteRoot error")
        } catch let error as BranchError {
            XCTAssertEqual(error, .cannotDeleteRoot)
        }
    }
}

// MARK: - UI Tests

class BranchCreationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testBranchCreationWorkflow() throws {
        // Navigate to a conversation
        app.tables["ConversationList"].cells.firstMatch.click()

        // Wait for messages to load
        let messageExists = app.staticTexts.matching(identifier: "MessageBubble").firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(messageExists, "Messages should be visible")

        // Right-click on a message
        let message = app.staticTexts.matching(identifier: "MessageBubble").element(boundBy: 3)
        message.rightClick()

        // Select "Create Branch from Here"
        app.menuItems["Create Branch from Here"].click()

        // Enter branch title
        let titleField = app.textFields["Branch title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.click()
        titleField.typeText("Alternative Solution")

        // Select copy strategy
        app.segmentedControls["Copy Strategy"].buttons["All previous"].click()

        // Create branch
        app.buttons["Create Branch"].click()

        // Verify new conversation is active
        XCTAssertTrue(app.staticTexts["Alternative Solution"].waitForExistence(timeout: 2))
    }

    func testBranchTreeVisualization() throws {
        // Navigate to conversation with branches
        app.tables["ConversationList"].cells.firstMatch.click()

        // Click "View Branches" button
        app.buttons["View Branches"].click()

        // Verify branch tree view is shown
        XCTAssertTrue(app.staticTexts["Branch Tree"].exists)

        // Verify tree nodes are visible
        let branchNodes = app.buttons.matching(identifier: "BranchNode")
        XCTAssertGreaterThan(branchNodes.count, 0, "Should show at least one branch node")

        // Click on a branch node
        branchNodes.element(boundBy: 1).click()

        // Verify conversation switches
        // (Additional assertions based on your UI structure)
    }
}
```

### Performance Optimization

```swift
// MARK: - Performance Optimizations

extension ConversationBranchManager {
    /// Optimized branch tree loading for large conversation trees
    func loadBranchTreeOptimized(
        for conversation: Conversation,
        maxDepth: Int = 10
    ) async -> BranchTree {
        // Use background context
        let backgroundContext = persistenceController.newBackgroundContext()

        return await backgroundContext.perform {
            // Batch fetch with prefetching
            let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "SELF == %@ OR parentConversation == %@",
                conversation,
                conversation
            )
            fetchRequest.relationshipKeyPathsForPrefetching = [
                "branches",
                "branchPoint",
                "messages"
            ]

            guard let conversations = try? backgroundContext.fetch(fetchRequest) else {
                return BranchTree(
                    root: self.buildNode(for: conversation, depth: 0),
                    totalBranches: 0,
                    maxDepth: 0,
                    createdAt: Date()
                )
            }

            // Build tree with prefetched data
            let root = self.buildNodeOptimized(
                for: conversation,
                depth: 0,
                maxDepth: maxDepth,
                prefetchedData: Set(conversations)
            )

            return BranchTree(
                root: root,
                totalBranches: self.countBranches(node: root),
                maxDepth: self.calculateMaxDepth(node: root),
                createdAt: Date()
            )
        }
    }

    /// Cache branch trees for faster subsequent loads
    private var branchTreeCache: [UUID: (tree: BranchTree, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 300  // 5 minutes

    func getCachedBranchTree(for conversation: Conversation) -> BranchTree? {
        guard let conversationID = conversation.id,
              let cached = branchTreeCache[conversationID] else {
            return nil
        }

        // Check cache validity
        if Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            return cached.tree
        }

        // Expired
        branchTreeCache.removeValue(forKey: conversationID)
        return nil
    }

    func cacheBranchTree(_ tree: BranchTree, for conversation: Conversation) {
        guard let conversationID = conversation.id else { return }
        branchTreeCache[conversationID] = (tree, Date())
    }
}
```

### Migration & Deployment

```swift
// MARK: - Core Data Migration

// Add to PersistenceController.swift

extension PersistenceController {
    /// Migration to add branching support
    func migrateToBranchingSupport() {
        // This would be part of Core Data model versioning
        // Version: NexusModel_v2.xcdatamodel

        // New attributes for Conversation entity:
        // - parentConversation: Conversation (optional, to-one)
        // - branches: Set<Conversation> (optional, to-many, inverse of parentConversation)
        // - branchPoint: Message (optional, to-one)
        // - branchTitle: String (optional)
        // - divergedAt: Date (optional)
        // - isMerged: Bool (default: false)
        // - mergedAt: Date (optional)

        // Migration policy: NSEntityMigrationPolicy subclass
        // handles setting default values for existing conversations
    }
}

class BranchingMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )

        guard let destinationInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            return
        }

        // Initialize new attributes with defaults
        destinationInstance.setValue(nil, forKey: "parentConversation")
        destinationInstance.setValue(NSSet(), forKey: "branches")
        destinationInstance.setValue(nil, forKey: "branchPoint")
        destinationInstance.setValue(nil, forKey: "branchTitle")
        destinationInstance.setValue(nil, forKey: "divergedAt")
        destinationInstance.setValue(false, forKey: "isMerged")
        destinationInstance.setValue(nil, forKey: "mergedAt")
    }
}
```

### Documentation

#### User Documentation

**Creating a Branch:**
1. Right-click on any message in a conversation
2. Select "Create Branch from Here"
3. Enter a title for your branch
4. Choose how many messages to include
5. Click "Create Branch"

**Viewing Branches:**
- Click the branch icon in the conversation header
- View a visual tree of all branches
- Click any branch to switch to it

**Merging Branches:**
1. Open the branch you want to merge
2. Click "Merge to Parent"
3. Choose merge strategy
4. Confirm merge

#### Developer Documentation

```swift
/**
 Branch Management System

 The branching system allows users to explore alternative conversation paths
 without losing context. It provides:

 - **Branch Creation**: Create new conversation branches from any message
 - **Tree Visualization**: View all branches in a hierarchical tree
 - **Branch Navigation**: Switch between branches seamlessly
 - **Branch Merging**: Merge branch content back to parent

 # Usage Example

 ```swift
 // Create a branch
 let branch = try await ConversationBranchManager.shared.createBranch(
     from: message,
     title: "Alternative Approach",
     copyStrategy: .includeAllPrevious
 )

 // View branch tree
 await ConversationBranchManager.shared.buildBranchTree(for: conversation)

 // Merge branch
 try await ConversationBranchManager.shared.mergeBranch(
     branch,
     strategy: .appendToParent
 )
 ```

 # Architecture

 - `ConversationBranchManager`: Main API for branch operations
 - `BranchTree`: Hierarchical representation of branches
 - `ConversationBranch`: Metadata about a single branch

 # Performance Considerations

 - Branch trees are cached for 5 minutes
 - Large trees use background context for building
 - Prefetching optimizes database queries

 - SeeAlso: `ConversationManager`, `PersistenceController`
 */
```

### Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Feature Adoption | 25% of active users create at least 1 branch within 30 days | Analytics tracking |
| Context Reduction | 40% reduction in context repetition | User surveys + message analysis |
| User Satisfaction | 80% report branches improve workflow | Post-feature survey (NPS) |
| Performance | < 100ms branch creation, < 200ms tree build | Performance monitoring |
| Error Rate | < 1% branch operations fail | Error logging |

---

## 1.2 Semantic Memory Search

**Status:** ✅ **IMPLEMENTED** - November 18, 2025

### Executive Summary

**Business Value:**
- **Problem:** Text search misses conceptually similar memories
- **Solution:** Vector embeddings + semantic similarity search
- **Impact:** 300% improvement in relevant memory retrieval

**Implementation Effort:** 3 weeks
**Priority:** HIGH
**Dependencies:** OpenAI Embeddings API, ChromaDB
**Risk Level:** MEDIUM (external API dependency)

### Technical Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Semantic Search Pipeline                     │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│  1. Memory Creation/Update                                │
│     ├─ User creates/edits memory                         │
│     ├─ Trigger: MemoryManager.createMemory()             │
│     └─ Event: memoryDidChange notification               │
└──────────┬───────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│  2. Embedding Generation                                  │
│     ├─ Extract: content + title + tags                   │
│     ├─ Call: OpenAI text-embedding-3-small API           │
│     ├─ Generate: 1536-dimensional vector                 │
│     ├─ Hash: SHA256 of content                           │
│     └─ Store: ChromaDB collection                        │
└──────────┬───────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│  3. Search Query Processing                               │
│     ├─ User enters query                                 │
│     ├─ Generate query embedding                          │
│     ├─ ChromaDB cosine similarity search                 │
│     └─ Apply filters (type, tier, date, similarity)      │
└──────────┬───────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│  4. Hybrid Ranking (Optional)                             │
│     ├─ Combine: semantic results + keyword search        │
│     ├─ Boost: items found in both                        │
│     ├─ Extract: relevant snippets                        │
│     └─ Rank: by combined score                           │
└──────────────────────────────────────────────────────────┘
```

### Data Models

```swift
// MARK: - File: Sources/NexusCore/SemanticSearchTypes.swift

import Foundation
import CryptoKit

/// Memory embedding for semantic search
public struct MemoryEmbedding: Codable, Identifiable, Sendable {
    public let id: UUID
    public let memoryID: UUID
    public let embedding: [Float]  // 1536 dimensions
    public let model: String
    public let generatedAt: Date
    public let contentHash: String  // SHA256
    public let tokenCount: Int

    public init(
        id: UUID = UUID(),
        memoryID: UUID,
        embedding: [Float],
        model: String = "text-embedding-3-small",
        generatedAt: Date = Date(),
        contentHash: String,
        tokenCount: Int
    ) {
        self.id = id
        self.memoryID = memoryID
        self.embedding = embedding
        self.model = model
        self.generatedAt = generatedAt
        self.contentHash = contentHash
        self.tokenCount = tokenCount
    }
}

/// Semantic search result with metadata
public struct SemanticSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let memory: Memory
    public let similarityScore: Float  // 0.0 - 1.0
    public let relevantSnippets: [Snippet]
    public let metadata: SearchMetadata

    public struct Snippet: Identifiable, Sendable {
        public let id: UUID
        public let text: String
        public let range: Range<String.Index>?
        public let relevanceScore: Float

        public init(id: UUID = UUID(), text: String, range: Range<String.Index>? = nil, relevanceScore: Float) {
            self.id = id
            self.text = text
            self.range = range
            self.relevanceScore = relevanceScore
        }
    }

    public struct SearchMetadata: Sendable {
        public let matchType: MatchType
        public let keywordMatches: [String]
        public let semanticDistance: Float
        public let contextRelevance: Float

        public enum MatchType: String, Sendable {
            case semantic
            case keyword
            case hybrid
        }
    }

    public init(
        id: UUID = UUID(),
        memory: Memory,
        similarityScore: Float,
        relevantSnippets: [Snippet],
        metadata: SearchMetadata
    ) {
        self.id = id
        self.memory = memory
        self.similarityScore = similarityScore
        self.relevantSnippets = relevantSnippets
        self.metadata = metadata
    }
}

/// Search filter options
public struct SemanticSearchFilter: Sendable {
    public var memoryTypes: [MemoryManager.MemoryType]?
    public var memoryTiers: [MemoryManager.MemoryTier]?
    public var dateRange: DateRange?
    public var tags: [String]?
    public var minSimilarity: Float  // 0.0 - 1.0
    public var maxResults: Int
    public var includeKeywordSearch: Bool
    public var sortBy: SortOption

    public struct DateRange: Sendable {
        public let start: Date
        public let end: Date
    }

    public enum SortOption: String, Sendable {
        case similarity
        case recency
        case relevance  // Hybrid of similarity + recency
    }

    public init(
        memoryTypes: [MemoryManager.MemoryType]? = nil,
        memoryTiers: [MemoryManager.MemoryTier]? = nil,
        dateRange: DateRange? = nil,
        tags: [String]? = nil,
        minSimilarity: Float = 0.7,
        maxResults: Int = 10,
        includeKeywordSearch: Bool = true,
        sortBy: SortOption = .similarity
    ) {
        self.memoryTypes = memoryTypes
        self.memoryTiers = memoryTiers
        self.dateRange = dateRange
        self.tags = tags
        self.minSimilarity = minSimilarity
        self.maxResults = maxResults
        self.includeKeywordSearch = includeKeywordSearch
        self.sortBy = sortBy
    }
}

/// Indexing progress
public struct IndexingProgress: Sendable {
    public let total: Int
    public let completed: Int
    public let currentMemory: String?
    public let estimatedTimeRemaining: TimeInterval?

    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
}
```

