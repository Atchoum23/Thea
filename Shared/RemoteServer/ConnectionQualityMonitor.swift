//
//  ConnectionQualityMonitor.swift
//  Thea
//
//  Real-time connection quality tracking for remote desktop sessions
//

import Combine
import Foundation

// MARK: - Connection Quality

public enum ConnectionQuality: String, Sendable, CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case unknown

    public var displayName: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .fair: "Fair"
        case .poor: "Poor"
        case .unknown: "Unknown"
        }
    }

    public var systemImage: String {
        switch self {
        case .excellent: "wifi"
        case .good: "wifi"
        case .fair: "wifi.exclamationmark"
        case .poor: "wifi.slash"
        case .unknown: "questionmark.circle"
        }
    }
}

// MARK: - Connection Quality Monitor

/// Tracks real-time connection quality metrics for remote desktop sessions
@MainActor
public class ConnectionQualityMonitor: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var quality: ConnectionQuality = .unknown
    @Published public private(set) var latencyMs: Double = 0
    @Published public private(set) var jitterMs: Double = 0
    @Published public private(set) var packetLossPercent: Double = 0
    @Published public private(set) var fps: Double = 0
    @Published public private(set) var bandwidthBps: Int64 = 0
    @Published public private(set) var roundTripSamples: Int = 0

    // MARK: - Internal Tracking

    private var latencyHistory: [Double] = []
    private var frameTimestamps: [Date] = []
    private var bytesSentInWindow: Int64 = 0
    private var bytesReceivedInWindow: Int64 = 0
    private var windowStartTime: Date = .init()
    private var pingsSent: Int = 0
    private var pongsReceived: Int = 0
    private var monitorTask: Task<Void, Never>?

    private let maxHistorySize = 60
    private let qualityUpdateInterval: TimeInterval = 2.0

    // MARK: - Initialization

    public init() {}

    // MARK: - Start / Stop

    /// Start periodic quality assessment
    public func start() {
        windowStartTime = Date()
        monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(qualityUpdateInterval * 1_000_000_000))
                await MainActor.run {
                    self.updateQuality()
                    self.updateBandwidth()
                    self.updateFPS()
                }
            }
        }
    }

    /// Stop monitoring
    public func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        quality = .unknown
    }

    // MARK: - Record Metrics

    /// Record a round-trip latency sample (from ping/pong)
    public func recordLatency(_ ms: Double) {
        latencyHistory.append(ms)
        if latencyHistory.count > maxHistorySize {
            latencyHistory.removeFirst()
        }
        roundTripSamples += 1

        // Update rolling average
        latencyMs = latencyHistory.suffix(10).reduce(0, +) / Double(min(latencyHistory.count, 10))

        // Calculate jitter (standard deviation of recent samples)
        let recentSamples = Array(latencyHistory.suffix(10))
        if recentSamples.count >= 2 {
            let mean = recentSamples.reduce(0, +) / Double(recentSamples.count)
            let variance = recentSamples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recentSamples.count)
            jitterMs = variance.squareRoot()
        }
    }

    /// Record that a frame was received
    public func recordFrame() {
        frameTimestamps.append(Date())
        if frameTimestamps.count > maxHistorySize {
            frameTimestamps.removeFirst()
        }
    }

    /// Record bytes transferred
    public func recordBytesSent(_ bytes: Int64) {
        bytesSentInWindow += bytes
    }

    /// Record bytes received
    public func recordBytesReceived(_ bytes: Int64) {
        bytesReceivedInWindow += bytes
    }

    /// Record a ping sent
    public func recordPingSent() {
        pingsSent += 1
    }

    /// Record a pong received
    public func recordPongReceived() {
        pongsReceived += 1
    }

    // MARK: - Quality Assessment

    private func updateQuality() {
        // Calculate packet loss
        if pingsSent > 0 {
            packetLossPercent = max(0, (1.0 - Double(pongsReceived) / Double(pingsSent)) * 100)
        }

        // Determine overall quality
        quality = assessQuality()
    }

    private func assessQuality() -> ConnectionQuality {
        guard roundTripSamples > 0 else { return .unknown }

        // Score based on latency (0-40 points)
        let latencyScore: Int
        switch latencyMs {
        case 0 ..< 20: latencyScore = 40
        case 20 ..< 50: latencyScore = 30
        case 50 ..< 100: latencyScore = 20
        case 100 ..< 200: latencyScore = 10
        default: latencyScore = 0
        }

        // Score based on jitter (0-30 points)
        let jitterScore: Int
        switch jitterMs {
        case 0 ..< 5: jitterScore = 30
        case 5 ..< 15: jitterScore = 20
        case 15 ..< 30: jitterScore = 10
        default: jitterScore = 0
        }

        // Score based on packet loss (0-30 points)
        let lossScore: Int
        switch packetLossPercent {
        case 0 ..< 1: lossScore = 30
        case 1 ..< 3: lossScore = 20
        case 3 ..< 10: lossScore = 10
        default: lossScore = 0
        }

        let totalScore = latencyScore + jitterScore + lossScore

        switch totalScore {
        case 80 ... 100: return .excellent
        case 60 ..< 80: return .good
        case 40 ..< 60: return .fair
        default: return .poor
        }
    }

    private func updateBandwidth() {
        let elapsed = Date().timeIntervalSince(windowStartTime)
        guard elapsed > 0 else { return }

        bandwidthBps = Int64(Double(bytesSentInWindow + bytesReceivedInWindow) * 8.0 / elapsed)

        // Reset window
        bytesSentInWindow = 0
        bytesReceivedInWindow = 0
        windowStartTime = Date()
    }

    private func updateFPS() {
        let now = Date()
        let recentFrames = frameTimestamps.filter { now.timeIntervalSince($0) < 2.0 }

        if recentFrames.count >= 2 {
            let timeSpan = recentFrames.last!.timeIntervalSince(recentFrames.first!)
            fps = timeSpan > 0 ? Double(recentFrames.count - 1) / timeSpan : 0
        } else {
            fps = 0
        }
    }

    // MARK: - Reset

    /// Reset all metrics
    public func reset() {
        latencyHistory.removeAll()
        frameTimestamps.removeAll()
        bytesSentInWindow = 0
        bytesReceivedInWindow = 0
        windowStartTime = Date()
        pingsSent = 0
        pongsReceived = 0
        roundTripSamples = 0
        latencyMs = 0
        jitterMs = 0
        packetLossPercent = 0
        fps = 0
        bandwidthBps = 0
        quality = .unknown
    }
}
