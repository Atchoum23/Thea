// MissionOrchestrator+Execution.swift
// Step implementations, error handling, progress, logging, and persistence

import Foundation
import OSLog

// MARK: - Step Implementations

@MainActor
extension MissionOrchestrator {
    func performValidation(_: MissionStep, mission: Mission) async throws {
        // Validate mission requirements
        log(.info, "Validating requirements...")

        guard mission.analysis.feasibility.feasible else {
            throw MissionError.validationFailed(mission.analysis.feasibility.blockers.joined(separator: ", "))
        }
    }

    func gatherResources(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Gathering resources...")
        // Gather any required resources
    }

    func saveCheckpoint(_ step: MissionStep, mission: Mission) async throws {
        log(.info, "Saving checkpoint...")

        checkpointData["mission_id"] = mission.id.uuidString
        checkpointData["phase"] = currentPhase?.order
        checkpointData["step"] = step.order
        checkpointData["timestamp"] = Date()

        // Save to persistent storage
        do {
            let data = try JSONSerialization.data(withJSONObject: checkpointData)
            UserDefaults.standard.set(data, forKey: "mission.checkpoint.\(mission.id)")
        } catch {
            logger.error("Failed to serialize checkpoint for mission \(mission.id): \(error.localizedDescription)")
        }
    }

    func performPlanning(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Planning execution...")
        // AI-assisted planning
    }

    func generateCode(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Generating code...")
        // Use AI to generate code
    }

    func modifyCode(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Modifying code...")
        // Use AI to modify existing code
    }

    func performFileOperation(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Performing file operations...")
        // Create/modify/delete files
    }

    func collectData(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Collecting data...")
        // Gather required data
    }

    func processData(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Processing data...")
        // Process collected data
    }

    func performAIAnalysis(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Performing AI analysis...")
        // AI-powered analysis
    }

    func performBuild(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Building project...")
        // Trigger build system
    }

    func runTests(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Running tests...")
        // Execute test suite
    }

    func deploy(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Deploying...")
        // Deploy artifacts
    }

    func generateReport(_: MissionStep, mission: Mission) async throws {
        log(.info, "Generating report...")

        let report = MissionReport(
            missionId: mission.id,
            goal: mission.goal,
            status: mission.status,
            phasesCompleted: mission.phases.count { $0.status == .completed },
            totalPhases: mission.phases.count,
            duration: mission.startedAt.map { Date().timeIntervalSince($0) },
            logs: logs,
            generatedAt: Date()
        )

        mission.report = report
    }

    func cleanupMission(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Cleaning up...")
        // Clean up temporary resources
        checkpointData.removeAll()
        retryCount.removeAll()
    }

    func executeGeneric(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Executing generic task...")
        // Generic execution
    }
}

// MARK: - Error Handling

@MainActor
extension MissionOrchestrator {
    func handleMissionError(_ mission: Mission, error: Error) async {
        mission.status = .failed
        mission.error = error.localizedDescription

        log(.error, "Mission failed: \(error.localizedDescription)")

        activeMission = nil
        currentPhase = nil
        currentStep = nil

        // Save to history
        missionHistory.insert(mission, at: 0)
        saveMissionHistory()

        // Notify
        NotificationCenter.default.post(name: .missionFailed, object: mission)
    }
}

// MARK: - Progress

@MainActor
extension MissionOrchestrator {
    func updateProgress(mission: Mission, phaseIndex: Int) {
        let totalSteps = mission.phases.reduce(0) { $0 + $1.steps.count }
        let completedSteps = mission.phases.prefix(phaseIndex).reduce(0) { $0 + $1.steps.count { $0.status == .completed }}
        let currentPhaseCompleted = currentPhase?.steps.count { $0.status == .completed } ?? 0

        overallProgress = Double(completedSteps + currentPhaseCompleted) / Double(totalSteps)
    }
}

// MARK: - Logging

@MainActor
extension MissionOrchestrator {
    func log(_ level: LogLevel, _ message: String) {
        let entry = MissionLog(
            timestamp: Date(),
            level: level,
            message: message,
            phase: currentPhase?.name,
            step: currentStep?.name
        )

        logs.append(entry)

        switch level {
        case .info: logger.info("\(message)")
        case .success: logger.info("✓ \(message)")
        case .warning: logger.warning("⚠ \(message)")
        case .error: logger.error("✗ \(message)")
        }
    }
}

// MARK: - Persistence

@MainActor
extension MissionOrchestrator {
    func loadMissionHistory() {
        if let data = UserDefaults.standard.data(forKey: "mission.history") {
            do {
                missionHistory = try JSONDecoder().decode([Mission].self, from: data)
            } catch {
                logger.error("Failed to decode mission history: \(error.localizedDescription)")
            }
        }
    }

    func saveMissionHistory() {
        // Keep last 50 missions
        let toSave = Array(missionHistory.prefix(50))
        do {
            let data = try JSONEncoder().encode(toSave)
            UserDefaults.standard.set(data, forKey: "mission.history")
        } catch {
            logger.error("Failed to encode mission history: \(error.localizedDescription)")
        }
    }
}
