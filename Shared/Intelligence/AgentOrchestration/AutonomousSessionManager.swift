// AutonomousSessionManager.swift
// Thea — AQ3: Autonomous Session Watchdog
//
// DUAL-PURPOSE zero-monitoring stale-session watchdog:
//
// 1. DEV MODE: Monitors git commit staleness for autonomous coding sessions.
//    If no git commit in `staleThreshold` minutes, fires one macOS notification.
//
// 2. USER MODE: Monitors AgentOrchestrator task heartbeats for Thea's own
//    multi-step AI tasks (research + summarize, health analysis, code runs).
//    AgentOrchestrator calls heartbeat() on each subtask completion, resetting
//    the stale timer. If Thea's tasks stall, one notification fires.
//
// Policy: SILENT during progress. ONE notification only if stalled. Never spam.
//
// @MainActor — reads PersonalParameters.shared directly (same isolation).
// Stale threshold from PersonalParameters — SelfTuningEngine adapts based on task type + time of day.

import Foundation
import OSLog
import UserNotifications

// MARK: - AutonomousSessionManager

@MainActor
final class AutonomousSessionManager: ObservableObject {
    static let shared = AutonomousSessionManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AutonomousSessionManager")

    // MARK: - Config

    /// Dynamic stale threshold from PersonalParameters (SelfTuningEngine adapts)
    private var staleThreshold: TimeInterval {
        PersonalParameters.shared.agentStaleThresholdMinutes * 60
    }

    // MARK: - State

    private var watchdog: Timer?
    private let repoPath: String
    private var lastUserTaskHeartbeat: Date = .now
    private var staleNotificationSent = false

    // MARK: - Init

    init(repoPath: String = "/Users/alexis/Documents/IT & Tech/MyApps/Thea") {
        self.repoPath = repoPath
    }

    // MARK: - Session Lifecycle

    func startSession() {
        staleNotificationSent = false
        lastUserTaskHeartbeat = .now
        startWatchdog()
        logger.info("AutonomousSessionManager: session started — stale threshold \(Int(self.staleThreshold / 60))min")
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func stopSession() {
        watchdog?.invalidate()
        watchdog = nil
        logger.info("AutonomousSessionManager: session stopped")
    }

    // MARK: - USER MODE: Heartbeat from AgentOrchestrator

    /// Called by AgentOrchestrator on each subtask completion.
    /// Resets the stale timer so Thea's autonomous tasks don't trigger false alerts.
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func heartbeat() {
        lastUserTaskHeartbeat = .now
        if staleNotificationSent {
            staleNotificationSent = false
            logger.info("AutonomousSessionManager: heartbeat received — stale flag reset")
        }
    }

    // MARK: - Private

    private func startWatchdog() {
        watchdog?.invalidate()
        // Check every 5 minutes
        watchdog = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkStaleness()
            }
        }
    }

    private func checkStaleness() async {
        guard !staleNotificationSent else { return }

        let devElapsed = gitCommitAge()
        let userElapsed = Date.now.timeIntervalSince(lastUserTaskHeartbeat)
        let maxElapsed = max(devElapsed, userElapsed)

        guard maxElapsed > staleThreshold else { return }

        staleNotificationSent = true

        let mins = Int(maxElapsed / 60)
        let source = devElapsed > userElapsed ? "git commit" : "Thea agent task"

        logger.warning("AutonomousSessionManager: STALE — \(mins)min since last \(source)")

        let content = UNMutableNotificationContent()
        content.title = "Thea Agent Stalled"
        content.body = "\(mins) min since last \(source) — may need attention"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: "stale-\(Int(Date.now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("AutonomousSessionManager: notification failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Git Commit Age (DEV MODE)

    /// Returns seconds since the last git commit in the repo.
    private func gitCommitAge() -> TimeInterval {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repoPath, "log", "-1", "--format=%ct"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error("AutonomousSessionManager: git log failed — \(error.localizedDescription)")
            return 0
        }

        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"

        guard let timestamp = TimeInterval(raw), timestamp > 0 else { return 0 }
        return Date.now.timeIntervalSince1970 - timestamp
        #else
        // iOS: git monitoring not available (Process API unavailable)
        return 0
        #endif
    }
}
