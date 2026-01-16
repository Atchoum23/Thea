// TaskDecomposer.swift
import Foundation
import OSLog

public actor TaskDecomposer {
    public static let shared = TaskDecomposer()

    private let logger = Logger(subsystem: "com.thea.app", category: "TaskDecomposer")

    public struct Task: Sendable, Identifiable {
        public let id: UUID
        public let type: TaskType
        public let description: String
        public let file: FileRequirement?
        public let codeToGenerate: String?
        public let dependencies: [UUID]
        public var status: TaskStatus

        public enum TaskType: String, Sendable {
            case createFile
            case editFile
            case generateCode
            case runBuild
            case fixErrors
            case verifyChecklist
            case createDMG
            case requestApproval
        }

        public enum TaskStatus: String, Sendable {
            case pending
            case inProgress
            case completed
            case failed
            case skipped
        }
    }

    public struct TaskPlan: Sendable {
        public let phaseId: String
        public let tasks: [Task]
        public let estimatedDuration: TimeInterval
    }

    // MARK: - Public API

    public func decompose(phase: PhaseDefinition) async -> TaskPlan {
        logger.info("Decomposing phase \(phase.number): \(phase.title)")

        var tasks: [Task] = []
        var taskIdMap: [String: UUID] = [:]

        // 1. Create tasks for each file requirement
        for (index, file) in phase.files.enumerated() {
            let taskId = UUID()
            taskIdMap[file.path] = taskId

            let task: Task
            switch file.status {
            case .new:
                task = Task(
                    id: taskId,
                    type: .createFile,
                    description: "Create new file: \(file.path)",
                    file: file,
                    codeToGenerate: file.codeHints.first,
                    dependencies: index > 0 ? [tasks[index - 1].id] : [],
                    status: .pending
                )
            case .edit:
                task = Task(
                    id: taskId,
                    type: .editFile,
                    description: "Edit existing file: \(file.path)",
                    file: file,
                    codeToGenerate: file.codeHints.first,
                    dependencies: index > 0 ? [tasks[index - 1].id] : [],
                    status: .pending
                )
            case .exists:
                task = Task(
                    id: taskId,
                    type: .verifyChecklist,
                    description: "Verify file exists: \(file.path)",
                    file: file,
                    codeToGenerate: nil,
                    dependencies: [],
                    status: .pending
                )
            }
            tasks.append(task)
        }

        // 2. Add build task after all files
        let buildTaskId = UUID()
        let buildTask = Task(
            id: buildTaskId,
            type: .runBuild,
            description: "Build project and verify compilation",
            file: nil,
            codeToGenerate: nil,
            dependencies: tasks.map { $0.id },
            status: .pending
        )
        tasks.append(buildTask)

        // 3. Add error fix task (conditional)
        let fixTaskId = UUID()
        let fixTask = Task(
            id: fixTaskId,
            type: .fixErrors,
            description: "Fix any compilation errors using AutonomousBuildLoop",
            file: nil,
            codeToGenerate: nil,
            dependencies: [buildTaskId],
            status: .pending
        )
        tasks.append(fixTask)

        // 4. Add verification tasks
        for item in phase.verificationChecklist {
            let verifyTask = Task(
                id: UUID(),
                type: .verifyChecklist,
                description: item.description,
                file: nil,
                codeToGenerate: nil,
                dependencies: [fixTaskId],
                status: item.completed ? .completed : .pending
            )
            tasks.append(verifyTask)
        }

        // 5. Add approval gate
        let approvalTask = Task(
            id: UUID(),
            type: .requestApproval,
            description: "Request human approval before finalizing phase",
            file: nil,
            codeToGenerate: nil,
            dependencies: tasks.map { $0.id },
            status: .pending
        )
        tasks.append(approvalTask)

        // 6. Add DMG creation if deliverable specified
        if let deliverable = phase.deliverable {
            let dmgTask = Task(
                id: UUID(),
                type: .createDMG,
                description: "Create DMG: \(deliverable)",
                file: nil,
                codeToGenerate: nil,
                dependencies: [approvalTask.id],
                status: .pending
            )
            tasks.append(dmgTask)
        }

        let estimatedDuration = Double(phase.estimatedHours.lowerBound) * 3_600

        logger.info("Created \(tasks.count) tasks for phase \(phase.number)")

        return TaskPlan(
            phaseId: phase.id,
            tasks: tasks,
            estimatedDuration: estimatedDuration
        )
    }
}
