// ReliabilityMonitor.swift
// Thea V2
//
// Reliability Monitor - Self-healing and fault tolerance system
// Implements circuit breakers, graceful degradation, and recovery

import Foundation
import OSLog

// MARK: - Reliability Monitor

/// Monitors system health and implements self-healing behaviors
@MainActor
public final class ReliabilityMonitor: ObservableObject {

    public static let shared = ReliabilityMonitor()

    private let logger = Logger(subsystem: "app.thea.reliability", category: "ReliabilityMonitor")

    // MARK: - State

    @Published public private(set) var systemHealth: SystemHealth = SystemHealth()
    @Published public private(set) var circuitBreakers: [String: CircuitBreaker] = [:]
    @Published public private(set) var degradationLevel: DegradationLevel = .none

    // MARK: - Configuration

    public var healthCheckInterval: TimeInterval = 60
    public var defaultFailureThreshold: Int = 5
    public var defaultRecoveryTimeout: TimeInterval = 60

    // MARK: - Health Monitoring

    private var healthCheckTask: Task<Void, Never>?

    public func startMonitoring() {
        healthCheckTask = Task {
            while !Task.isCancelled {
                await performHealthCheck()
                try? await Task.sleep(for: .seconds(healthCheckInterval))
            }
        }
        logger.info("Reliability monitoring started")
    }

    public func stopMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    private func performHealthCheck() async {
        var health = SystemHealth()
        health.lastCheckAt = Date()
        health.memoryStatus = checkMemoryUsage()
        health.overallScore = health.memoryStatus.isOperational ? 1.0 : 0.5
        health.isHealthy = health.overallScore >= 0.7
        systemHealth = health
        updateDegradationLevel(health)
    }

    private func checkMemoryUsage() -> ComponentStatus {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let used = result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 / 1024.0 : 0
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0
        let usagePercent = used / total

        return ComponentStatus(name: "Memory", isOperational: usagePercent < 0.9, lastError: usagePercent >= 0.9 ? "High memory" : nil)
    }

    private func updateDegradationLevel(_ health: SystemHealth) {
        let newLevel: DegradationLevel = health.overallScore >= 0.9 ? .none :
                                         health.overallScore >= 0.7 ? .light :
                                         health.overallScore >= 0.5 ? .moderate : .heavy
        if newLevel != degradationLevel {
            logger.warning("Degradation: \(newLevel.rawValue)")
            degradationLevel = newLevel
        }
    }

    public func getCircuitBreaker(for service: String) -> CircuitBreaker {
        if let existing = circuitBreakers[service] { return existing }
        let breaker = CircuitBreaker(name: service, failureThreshold: defaultFailureThreshold, recoveryTimeout: defaultRecoveryTimeout)
        circuitBreakers[service] = breaker
        return breaker
    }
}

// MARK: - Supporting Types

public struct SystemHealth: Sendable {
    public var isHealthy: Bool = true
    public var overallScore: Float = 1.0
    public var lastCheckAt: Date = Date()
    public var memoryStatus: ComponentStatus = ComponentStatus(name: "Memory", isOperational: true, lastError: nil)
}

public struct ComponentStatus: Sendable {
    public let name: String
    public let isOperational: Bool
    public let lastError: String?
}

public struct CircuitBreaker: Sendable {
    public let name: String
    public var state: CircuitState = .closed
    public var failureCount: Int = 0
    public var failureThreshold: Int
    public var recoveryTimeout: TimeInterval

    public enum CircuitState: String, Sendable { case closed, open, halfOpen }
}

public enum DegradationLevel: String, Sendable {
    case none = "Normal"
    case light = "Light Degradation"
    case moderate = "Moderate Degradation"
    case heavy = "Heavy Degradation"
}
