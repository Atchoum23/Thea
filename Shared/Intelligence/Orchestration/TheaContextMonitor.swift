//
//  TheaContextMonitor.swift
//  Thea
//
//  Background context pressure monitor for sub-agent sessions.
//  Proactively triggers summarization before context windows overflow.
//  Reallocates token budgets from completed agents to active ones.
//

import Foundation
import os.log

// MARK: - TheaContextMonitor

/// Monitors context pressure across all active agent sessions.
/// Triggers preemptive summarization and budget reallocation.
// periphery:ignore - Reserved: TheaContextMonitor type reserved for future feature activation
actor TheaContextMonitor {
    private let logger = Logger(subsystem: "app.thea", category: "ContextMonitor")
    private var monitorTask: Task<Void, Never>?
    private let checkInterval: TimeInterval = 5.0

    // MARK: - Start / Stop

    func start() {
        guard monitorTask == nil else { return }
        monitorTask = Task {
            logger.info("Context monitor started")
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                } catch {
                    break
                }
                await checkAllSessions()
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        logger.info("Context monitor stopped")
    }

    // MARK: - Check Sessions

    private func checkAllSessions() async {
        let orchestrator = await MainActor.run { TheaAgentOrchestrator.shared }
        let sessions = await MainActor.run { orchestrator.activeSessions }

        for session in sessions {
            let pressure = await MainActor.run { session.contextPressure }

            switch pressure {
            case .nominal:
                break
            case .elevated:
                logger.debug("Agent \(session.id.uuidString.prefix(8)): elevated pressure, scheduling summarization")
                // Schedule summarization at next natural pause
                await summarizeIfNeeded(session)
            case .critical:
                logger.warning("Agent \(session.id.uuidString.prefix(8)): CRITICAL pressure, summarizing now")
                await summarizeIfNeeded(session)
            case .exceeded:
                logger.error("Agent \(session.id.uuidString.prefix(8)): EXCEEDED — context window at risk")
                await summarizeIfNeeded(session)
            }
        }

        // Reallocate budget after any changes
        await MainActor.run {
            orchestrator.reallocateContextBudget()
        }
    }

    private func summarizeIfNeeded(_ session: TheaAgentSession) async {
        let lastSummarized = await MainActor.run { session.lastSummarizedAt }
        let msgCount = await MainActor.run { session.messages.count }

        // Don't summarize if we just did, or if there are too few messages
        if let last = lastSummarized, Date().timeIntervalSince(last) < 10 { return }
        if msgCount <= 3 { return }

        // Use the runner to perform summarization
        do {
            let (provider, model, _) = try await ChatManager.shared.selectProviderAndModel(
                for: "summarize conversation"
            )
            let runner = TheaAgentRunner()
            await runner.summarizeContext(session: session, provider: provider, model: model)
        } catch {
            logger.error("Summarization failed for agent \(session.id.uuidString.prefix(8)): \(error.localizedDescription)")
        }
    }
}
