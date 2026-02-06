//
//  OrchestratorTypes.swift
//  Thea
//
//  Supporting types for Orchestrator Settings views
//  Extracted from OrchestratorSettingsView.swift for better code organization
//

import Foundation

#if os(macOS)

// MARK: - Execution Statistics

/// Statistics for orchestrator execution
struct ExecutionStatistics {
    var activeAgents: Int = 0
    var queuedTasks: Int = 0
    var currentTasks: [CurrentTask] = []
    var avgResponseTime: Double = 1.85
    var successRate: Double = 0.96
    var successfulTasks: Int = 142
    var failedTasks: Int = 6
    var costToday: Double = 0.0234
    var costThisMonth: Double = 1.87
    var tokensUsedToday: Int = 45_230
    var recentResponseTimes: [Double] = [1.2, 0.8, 2.1, 1.5, 0.9, 3.2, 1.1, 0.7, 1.8, 1.3]
    var modelUsage: [String: Int] = [
        "local-any": 45,
        "anthropic/claude-sonnet-4": 38,
        "openai/gpt-4o-mini": 32,
        "openai/gpt-4o": 18,
        "local-large": 15
    ]
    var totalExecutions: Int = 148
    var recentExecutions: [ExecutionRecord] = [
        ExecutionRecord(
            id: UUID(),
            taskType: "Code Generation",
            model: "anthropic/claude-sonnet-4",
            responseTime: 2.3,
            tokensUsed: 1250,
            success: true,
            timestamp: Date().addingTimeInterval(-300),
            errorMessage: ""
        ),
        ExecutionRecord(
            id: UUID(),
            taskType: "Simple QA",
            model: "local-any",
            responseTime: 0.8,
            tokensUsed: 320,
            success: true,
            timestamp: Date().addingTimeInterval(-600),
            errorMessage: ""
        ),
        ExecutionRecord(
            id: UUID(),
            taskType: "Analysis",
            model: "openai/gpt-4o",
            responseTime: 4.1,
            tokensUsed: 2100,
            success: true,
            timestamp: Date().addingTimeInterval(-900),
            errorMessage: ""
        )
    ]
}

// MARK: - Current Task

struct CurrentTask: Identifiable {
    let id = UUID()
    let description: String
    let model: String
}

// MARK: - Execution Record

struct ExecutionRecord: Identifiable {
    let id: UUID
    let taskType: String
    let model: String
    let responseTime: Double
    let tokensUsed: Int
    let success: Bool
    let timestamp: Date
    let errorMessage: String
}

#endif
