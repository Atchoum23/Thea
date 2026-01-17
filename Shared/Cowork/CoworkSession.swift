#if os(macOS)
import Foundation

/// Represents a Cowork work session
@MainActor
@Observable
final class CoworkSession: Identifiable {
    let id: UUID
    var name: String
    var workingDirectory: URL
    var steps: [CoworkStep]
    var artifacts: [CoworkArtifact]
    var context: CoworkContext
    var taskQueue: CoworkTaskQueue
    var status: SessionStatus
    var createdAt: Date
    var lastActivityAt: Date
    var error: String?
    var progress: Double

    enum SessionStatus: String, CaseIterable {
        case idle = "Idle"
        case planning = "Planning"
        case awaitingApproval = "Awaiting Approval"
        case executing = "Executing"
        case paused = "Paused"
        case completed = "Completed"
        case failed = "Failed"

        var icon: String {
            switch self {
            case .idle: return "circle"
            case .planning: return "brain.head.profile"
            case .awaitingApproval: return "hand.raised"
            case .executing: return "play.circle.fill"
            case .paused: return "pause.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .idle: return "gray"
            case .planning: return "purple"
            case .awaitingApproval: return "yellow"
            case .executing: return "blue"
            case .paused: return "orange"
            case .completed: return "green"
            case .failed: return "red"
            }
        }

        var isActive: Bool {
            self == .planning || self == .executing
        }
    }

    init(
        id: UUID = UUID(),
        name: String = "New Session",
        workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.steps = []
        self.artifacts = []
        self.context = CoworkContext(workingDirectory: workingDirectory)
        self.taskQueue = CoworkTaskQueue()
        self.status = .idle
        self.createdAt = Date()
        self.lastActivityAt = Date()
        self.progress = 0
    }

    // MARK: - Session Control

    func start() {
        status = .planning
        lastActivityAt = Date()
    }

    func execute() {
        status = .executing
        lastActivityAt = Date()
    }

    func pause() {
        status = .paused
        taskQueue.pause()
        lastActivityAt = Date()
    }

    func resume() {
        status = .executing
        lastActivityAt = Date()
    }

    func complete() {
        status = .completed
        progress = 1.0
        lastActivityAt = Date()
    }

    func fail(with error: String) {
        status = .failed
        self.error = error
        lastActivityAt = Date()
    }

    func reset() {
        status = .idle
        steps.removeAll()
        progress = 0
        error = nil
        lastActivityAt = Date()
    }

    // MARK: - Step Management

    func addStep(_ step: CoworkStep) {
        steps.append(step)
        updateProgress()
        lastActivityAt = Date()
    }

    func addSteps(_ newSteps: [CoworkStep]) {
        steps.append(contentsOf: newSteps)
        updateProgress()
        lastActivityAt = Date()
    }

    func updateStep(_ stepId: UUID, with update: (inout CoworkStep) -> Void) {
        if let index = steps.firstIndex(where: { $0.id == stepId }) {
            update(&steps[index])
            updateProgress()
            lastActivityAt = Date()
        }
    }

    func startStep(_ stepId: UUID) {
        updateStep(stepId) { $0.start() }
    }

    func completeStep(_ stepId: UUID) {
        updateStep(stepId) { $0.complete() }
    }

    func failStep(_ stepId: UUID, error: String) {
        updateStep(stepId) { $0.fail(with: error) }
    }

    var currentStep: CoworkStep? {
        steps.first { $0.status == .inProgress }
    }

    var nextPendingStep: CoworkStep? {
        steps.first { $0.status == .pending }
    }

    var completedSteps: [CoworkStep] {
        steps.filter { $0.status == .completed }
    }

    // MARK: - Artifact Management

    func addArtifact(_ artifact: CoworkArtifact) {
        artifacts.append(artifact)
        lastActivityAt = Date()
    }

    func addArtifact(from url: URL, isIntermediate: Bool = false, stepId: UUID? = nil) {
        if let artifact = CoworkArtifact.from(url: url, isIntermediate: isIntermediate, stepId: stepId) {
            artifacts.append(artifact)
            lastActivityAt = Date()
        }
    }

    func removeArtifact(_ artifactId: UUID) {
        artifacts.removeAll { $0.id == artifactId }
    }

    var finalArtifacts: [CoworkArtifact] {
        artifacts.filter { !$0.isIntermediate }
    }

    // MARK: - Progress

    private func updateProgress() {
        guard !steps.isEmpty else {
            progress = 0
            return
        }

        let completed = steps.filter { $0.status == .completed || $0.status == .skipped }.count
        progress = Double(completed) / Double(steps.count)
    }

    var estimatedTimeRemaining: TimeInterval? {
        let completed = completedSteps
        guard !completed.isEmpty else { return nil }

        let avgDuration = completed.compactMap(\.duration).reduce(0, +) / Double(completed.count)
        let remaining = steps.filter { $0.status == .pending || $0.status == .inProgress }.count

        return avgDuration * Double(remaining)
    }

    // MARK: - Summary

    var summary: SessionSummary {
        SessionSummary(
            totalSteps: steps.count,
            completedSteps: completedSteps.count,
            failedSteps: steps.filter { $0.status == .failed }.count,
            totalArtifacts: artifacts.count,
            finalArtifacts: finalArtifacts.count,
            totalSize: artifacts.totalSize,
            duration: lastActivityAt.timeIntervalSince(createdAt),
            filesAccessed: context.uniqueFilesAccessed.count,
            filesModified: context.modifiedFiles.count
        )
    }

    struct SessionSummary {
        let totalSteps: Int
        let completedSteps: Int
        let failedSteps: Int
        let totalArtifacts: Int
        let finalArtifacts: Int
        let totalSize: Int64
        let duration: TimeInterval
        let filesAccessed: Int
        let filesModified: Int

        var successRate: Double {
            guard totalSteps > 0 else { return 0 }
            return Double(completedSteps) / Double(totalSteps)
        }
    }
}

// MARK: - Codable Support

extension CoworkSession {
    struct CodableRepresentation: Codable {
        let id: UUID
        let name: String
        let workingDirectory: URL
        let steps: [CoworkStep]
        let artifacts: [CoworkArtifact]
        let context: CoworkContext
        let status: String
        let createdAt: Date
        let lastActivityAt: Date
        let error: String?
        let progress: Double
    }

    func toCodable() -> CodableRepresentation {
        CodableRepresentation(
            id: id,
            name: name,
            workingDirectory: workingDirectory,
            steps: steps,
            artifacts: artifacts,
            context: context,
            status: status.rawValue,
            createdAt: createdAt,
            lastActivityAt: lastActivityAt,
            error: error,
            progress: progress
        )
    }

    static func from(_ codable: CodableRepresentation) -> CoworkSession {
        let session = CoworkSession(
            id: codable.id,
            name: codable.name,
            workingDirectory: codable.workingDirectory
        )
        session.steps = codable.steps
        session.artifacts = codable.artifacts
        session.context = codable.context
        session.status = SessionStatus(rawValue: codable.status) ?? .idle
        session.createdAt = codable.createdAt
        session.lastActivityAt = codable.lastActivityAt
        session.error = codable.error
        session.progress = codable.progress
        return session
    }
}

#endif
