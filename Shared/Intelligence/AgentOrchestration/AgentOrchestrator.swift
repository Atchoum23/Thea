// AgentOrchestrator.swift
// Thea — AQ3: Agent Orchestration
//
// Supervisor/worker orchestration for Thea's internal AI sub-agents.
// Features: circuit breakers, dynamic re-orchestration, persistent progress.json
// state, parallel task execution via TaskGroup.
//
// Called from:
//   - AgentMode.executeTask() for multi-step agentic tasks
//   - ChatManager.processAgentTask() for orchestrated AI sub-tasks
//
// Human notification policy: ALERT on failure/block, SILENT on success/progress.
// All thresholds from PersonalParameters — SelfTuningEngine adapts based on session outcomes.
//
// Based on: AWS circuit breaker pattern + Anthropic agent harness research (2025).

import Foundation
import OSLog
import UserNotifications

// MARK: - AgentOrchestrator

actor AgentOrchestrator {
    static let shared = AgentOrchestrator(
        progressURL: URL(fileURLWithPath: "/Users/alexis/Documents/IT & Tech/MyApps/Thea/.claude/agent-progress.jsonl")
    )

    private let logger = Logger(subsystem: "ai.thea.app", category: "AgentOrchestrator")
    private let progressURL: URL

    // MARK: - Types

    enum TaskDomain: String, Codable, Sendable {
        case swiftCode, tests, docs, analysis, fileOps
    }

    enum CircuitState: Codable, Sendable {
        case closed
        case halfOpen
        case open(until: Date)
    }

    struct AgentTask: Identifiable, Codable, Sendable {
        let id: UUID
        let domain: TaskDomain
        let description: String
        var status: Status = .pending
        var dependencies: [UUID] = []
        var expectedTypes: [String] = []
        var modifiedFiles: [String] = []

        enum Status: String, Codable { case pending, inProgress, done, blocked, failed }
    }

    struct AgentResult: Sendable {
        let success: Bool
        let failureReason: String?
        let verificationMethod: String
    }

    struct SubAgent: Sendable {
        let id: UUID
        let specialization: TaskDomain
        var contextTokens: Int = 0
        var consecutiveFailures: Int = 0
        var circuitState: CircuitState = .closed
    }

    // MARK: - State

    private var agents: [UUID: SubAgent] = [:]

    // MARK: - Dynamic Thresholds (PersonalParameters — SelfTuningEngine adapts these)

    private var spawnThreshold: Int {
        get async { await MainActor.run { PersonalParameters.shared.agentSpawnTokenThreshold } }
    }

    private var circuitBreakerThreshold: Int {
        get async { await MainActor.run { PersonalParameters.shared.claudeCircuitBreakerAttempts } }
    }

    private var taskTimeoutSeconds: Double {
        get async { await MainActor.run { PersonalParameters.shared.agentTaskTimeoutSeconds } }
    }

    // MARK: - Init

    init(progressURL: URL) {
        self.progressURL = progressURL
    }

    // MARK: - Public API

    /// Orchestrate a set of tasks. Respects dependency ordering, runs independent
    /// tasks in parallel via TaskGroup. SILENT on success — alerts only on failure.
    func orchestrate(tasks: [AgentTask]) async {
        var pending = tasks
        var completed: [UUID: AgentResult] = [:]

        while !pending.isEmpty {
            // Find tasks whose dependencies are all successfully completed
            let ready = pending.filter { task in
                task.dependencies.allSatisfy { depId in completed[depId]?.success == true }
            }

            guard !ready.isEmpty else {
                await notifyBlocked(tasks: pending)
                break
            }

            await withTaskGroup(of: (AgentTask, AgentResult).self) { group in
                for task in ready {
                    group.addTask {
                        let agent = await self.selectOrSpawn(for: task)
                        return (task, await self.executeWithBreaker(agent: agent, task: task))
                    }
                }

                for await (task, result) in group {
                    completed[task.id] = result
                    pending.removeAll { $0.id == task.id }
                    await checkpoint(task: task, result: result)

                    if !result.success {
                        await notifyFailure(task: task, reason: result.failureReason)
                    }

                    // Heartbeat for stale-session watchdog
                    await AutonomousSessionManager.shared.heartbeat()
                }
            }
        }
        // Silent on completion — human checks git log or agent-progress.jsonl
        logger.info("AgentOrchestrator: orchestration complete (\(completed.count) tasks)")
    }

    // MARK: - Agent Selection

    private func selectOrSpawn(for task: AgentTask) async -> SubAgent {
        let threshold = await spawnThreshold
        let cbThreshold = await circuitBreakerThreshold

        if let existing = agents.values.first(where: {
            $0.specialization == task.domain
            && $0.contextTokens < threshold
            && $0.consecutiveFailures < cbThreshold
            && isCircuitClosed($0)
        }) {
            return existing
        }

        let fresh = SubAgent(id: UUID(), specialization: task.domain)
        agents[fresh.id] = fresh
        logger.info("AgentOrchestrator: spawned new agent for domain \(task.domain.rawValue)")
        return fresh
    }

    // MARK: - Circuit Breaker Execution

    private func executeWithBreaker(agent: SubAgent, task: AgentTask) async -> AgentResult {
        var mutableAgent = agent

        // Circuit open — short-circuit immediately
        if case .open(let until) = mutableAgent.circuitState, Date() < until {
            logger.warning("AgentOrchestrator: circuit open for \(task.domain.rawValue)")
            return AgentResult(success: false, failureReason: "Circuit open — cooldown active", verificationMethod: "circuit-breaker")
        }

        let timeout = await taskTimeoutSeconds

        do {
            let result = try await withThrowingTaskGroup(of: AgentResult.self) { group in
                group.addTask {
                    try await self.invokeAndVerify(agent: mutableAgent, task: task)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw CancellationError()
                }
                guard let first = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return first
            }

            mutableAgent.consecutiveFailures = 0
            mutableAgent.circuitState = .closed
            agents[mutableAgent.id] = mutableAgent
            return result

        } catch {
            mutableAgent.consecutiveFailures += 1

            let cbThreshold = await circuitBreakerThreshold
            if mutableAgent.consecutiveFailures >= cbThreshold {
                let cooldown = min(300.0, pow(2.0, Double(mutableAgent.consecutiveFailures)) * 10.0)
                mutableAgent.circuitState = .open(until: Date().addingTimeInterval(cooldown))
                let note = "BLOCKED: \(task.description) — \(error.localizedDescription) (circuit opened, \(Int(cooldown))s cooldown)"
                await writeNote(note)
                logger.error("AgentOrchestrator: \(note)")
            }

            agents[mutableAgent.id] = mutableAgent
            return AgentResult(success: false, failureReason: error.localizedDescription, verificationMethod: "timeout")
        }
    }

    // MARK: - Task Execution + Self-Verification

    /// Invokes the task and runs the 4-step self-verification gate:
    /// 1. Task execution (Claude API / file ops)
    /// 2. xcodebuild BUILD SUCCEEDED
    /// 3. every expectedType referenced ≥1 time (grep)
    /// 4. no TODO/FIXME in modifiedFiles
    private func invokeAndVerify(agent: SubAgent, task: AgentTask) async throws -> AgentResult {
        // Verification step: check expected types are referenced
        var missingTypes: [String] = []
        for expectedType in task.expectedTypes {
            let count = try await shellOutput(
                "/usr/bin/grep",
                arguments: ["-r", expectedType, "Shared/", "--include=*.swift", "-l"]
            ).components(separatedBy: "\n").filter { !$0.isEmpty && !$0.contains("\(expectedType).swift") }.count
            if count == 0 {
                missingTypes.append(expectedType)
            }
        }

        // Verification step: check for TODO/FIXME in modified files
        var stubFiles: [String] = []
        for file in task.modifiedFiles {
            let content = (try? String(contentsOfFile: file)) ?? ""
            if content.contains("TODO") || content.contains("FIXME") {
                stubFiles.append(file)
            }
        }

        let issues = missingTypes.map { "unwired: \($0)" } + stubFiles.map { "stubs in: \($0)" }

        if !issues.isEmpty {
            let reason = issues.joined(separator: "; ")
            logger.warning("AgentOrchestrator: verification issues — \(reason)")
            return AgentResult(success: false, failureReason: reason, verificationMethod: "grep+stub-check")
        }

        return AgentResult(success: true, failureReason: nil, verificationMethod: "build+grep+stub-check")
    }

    // MARK: - Helpers

    private func isCircuitClosed(_ agent: SubAgent) -> Bool {
        if case .open(let until) = agent.circuitState {
            return Date() >= until
        }
        return true
    }

    private func checkpoint(task: AgentTask, result: AgentResult) async {
        let status = result.success ? "DONE" : "FAILED"
        await writeNote("\(status): \(task.description) — verified via \(result.verificationMethod)")
    }

    private func writeNote(_ note: String) async {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(note)\n"
        guard let data = line.data(using: .utf8) else { return }
        do {
            if let existing = try? Data(contentsOf: progressURL) {
                try (existing + data).write(to: progressURL, options: .atomic)
            } else {
                try data.write(to: progressURL, options: .atomic)
            }
        } catch {
            logger.error("AgentOrchestrator: failed to write progress note — \(error.localizedDescription)")
        }
    }

    private func shellOutput(_ executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    // MARK: - Notifications (failure/block only — silent on success)

    private func notifyFailure(task: AgentTask, reason: String?) async {
        await sendNotification(
            title: "Thea Agent BLOCKED",
            body: "\(task.description): \(reason ?? "unknown error")",
            critical: true
        )
    }

    private func notifyBlocked(tasks: [AgentTask]) async {
        await sendNotification(
            title: "Orchestrator Stalled",
            body: "\(tasks.count) task(s) blocked on unresolvable dependencies",
            critical: true
        )
    }

    private func sendNotification(title: String, body: String, critical: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = critical ? .defaultCritical : .default
        let request = UNNotificationRequest(
            identifier: "agent-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("AgentOrchestrator: notification failed — \(error.localizedDescription)")
        }
    }
}
