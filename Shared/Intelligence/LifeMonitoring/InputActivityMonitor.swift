//
//  InputActivityMonitor.swift
//  Thea
//
//  Monitors mouse and keyboard input patterns for behavioral analysis.
//  Privacy-focused: tracks patterns and metrics, NOT content.
//
//  CAPABILITIES:
//  - Mouse tracking (movement, clicks, scrolls, dwell time)
//  - Keyboard tracking (patterns, speed, pauses - NOT content)
//  - Activity metrics (active vs idle, context switching)
//  - Focus session detection
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog

#if os(macOS)
import AppKit
import CoreGraphics
#endif

// MARK: - Input Activity Monitor

/// Monitors user input patterns for behavioral analysis
@MainActor
@Observable
public final class InputActivityMonitor {
    public static let shared = InputActivityMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "InputActivity")

    // MARK: - State

    public private(set) var isMonitoring: Bool = false
    public private(set) var currentSession: InputSession?
    public private(set) var todayMetrics: DailyInputMetrics = DailyInputMetrics()
    public private(set) var recentSessions: [InputSession] = []

    // MARK: - Configuration

    public var configuration: InputMonitorConfiguration = InputMonitorConfiguration()

    // MARK: - Private State

    #if os(macOS)
    private var globalEventMonitor: Any?
    #endif

    private var sessionStartTime: Date?
    private var lastActivityTime: Date = Date()
    private var idleCheckTimer: Timer?
    private var metricsTimer: Timer?
    private var sessionMouseClicks: Int = 0
    private var sessionMouseDistance: Double = 0
    private var sessionKeystrokes: Int = 0
    private var sessionScrollEvents: Int = 0
    private var sessionTypingBursts: [TypingBurst] = []
    private var lastMousePosition: CGPoint?
    private var currentAppBundleId: String = ""
    private var appSwitchCount: Int = 0
    private var lastAppBundleId: String = ""

    private init() {}

    // MARK: - Public API

    public func startMonitoring() {
        guard !isMonitoring else { return }
        logger.info("Starting input activity monitoring")
        isMonitoring = true
        startNewSession()
        setupEventMonitoring()
        startTimers()
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        logger.info("Stopping input activity monitoring")
        endCurrentSession()
        teardownEventMonitoring()
        stopTimers()
        isMonitoring = false
    }

    public func getCurrentFocusScore() -> Double {
        guard let session = currentSession else { return 0 }
        return session.focusScore
    }

    public func getCurrentTypingSpeed() -> Double {
        guard !sessionTypingBursts.isEmpty else { return 0 }
        let totalWords = sessionTypingBursts.reduce(0) { $0 + $1.wordCount }
        let totalMinutes = sessionTypingBursts.reduce(0.0) { $0 + $1.duration } / 60.0
        guard totalMinutes > 0 else { return 0 }
        return Double(totalWords) / totalMinutes
    }

    public func isInDeepFocus() -> Bool {
        let focusScore = getCurrentFocusScore()
        let hasLowAppSwitching = appSwitchCount < 3
        let hasConsistentActivity = sessionKeystrokes > 100 || sessionMouseClicks > 20
        return focusScore > 0.7 && hasLowAppSwitching && hasConsistentActivity
    }

    // MARK: - Private Implementation

    private func startNewSession() {
        sessionStartTime = Date()
        lastActivityTime = Date()
        sessionMouseClicks = 0
        sessionMouseDistance = 0
        sessionKeystrokes = 0
        sessionScrollEvents = 0
        sessionTypingBursts = []
        lastMousePosition = nil
        appSwitchCount = 0

        #if os(macOS)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            currentAppBundleId = frontApp.bundleIdentifier ?? "unknown"
            lastAppBundleId = currentAppBundleId
        }
        #endif
    }

    private func endCurrentSession() {
        guard let startTime = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        guard duration >= configuration.minSessionDuration else { return }

        let session = InputSession(
            id: UUID(),
            startTime: startTime,
            endTime: Date(),
            appBundleId: currentAppBundleId,
            mouseClicks: sessionMouseClicks,
            mouseDistance: sessionMouseDistance,
            keystrokes: sessionKeystrokes,
            typingSpeed: getCurrentTypingSpeed(),
            scrollEvents: sessionScrollEvents,
            idleTime: 0,
            focusScore: calculateFocusScore(),
            appSwitchCount: appSwitchCount
        )

        currentSession = session
        recentSessions.append(session)

        if recentSessions.count > configuration.maxRetainedSessions {
            recentSessions.removeFirst(recentSessions.count - configuration.maxRetainedSessions)
        }

        updateDailyMetrics(with: session)
    }

    private func setupEventMonitoring() {
        #if os(macOS)
        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .mouseMoved, .scrollWheel, .keyDown
        ]

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        #endif
    }

    private func teardownEventMonitoring() {
        #if os(macOS)
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        #endif
    }

    #if os(macOS)
    private func handleEvent(_ event: NSEvent) {
        lastActivityTime = Date()
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            sessionMouseClicks += 1
        case .mouseMoved:
            let currentPos = event.locationInWindow
            if let lastPos = lastMousePosition {
                let dx = currentPos.x - lastPos.x
                let dy = currentPos.y - lastPos.y
                sessionMouseDistance += sqrt(dx * dx + dy * dy)
            }
            lastMousePosition = currentPos
        case .scrollWheel:
            sessionScrollEvents += 1
        case .keyDown:
            sessionKeystrokes += 1
            recordTypingBurst()
        default:
            break
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        if bundleId != lastAppBundleId {
            appSwitchCount += 1
            lastAppBundleId = bundleId
            currentAppBundleId = bundleId
        }
    }
    #endif

    private func recordTypingBurst() {
        let now = Date()
        if let lastBurst = sessionTypingBursts.last,
           now.timeIntervalSince(lastBurst.endTime) < 2.0 {
            var updatedBurst = lastBurst
            updatedBurst.endTime = now
            updatedBurst.keystrokeCount += 1
            if lastBurst.keystrokeCount % 5 == 0 { updatedBurst.wordCount += 1 }
            sessionTypingBursts[sessionTypingBursts.count - 1] = updatedBurst
        } else {
            sessionTypingBursts.append(TypingBurst(startTime: now, endTime: now, keystrokeCount: 1, wordCount: 0))
        }
    }

    private func startTimers() {
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
        metricsTimer = Timer.scheduledTimer(withTimeInterval: configuration.sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMetrics() }
        }
    }

    private func stopTimers() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
        metricsTimer?.invalidate()
        metricsTimer = nil
    }

    private func checkIdle() {
        let idleDuration = Date().timeIntervalSince(lastActivityTime)
        if idleDuration > configuration.idleTimeout {
            endCurrentSession()
            startNewSession()
        }
    }

    private func sampleMetrics() {
        guard let startTime = sessionStartTime else { return }
        currentSession = InputSession(
            id: currentSession?.id ?? UUID(),
            startTime: startTime,
            endTime: Date(),
            appBundleId: currentAppBundleId,
            mouseClicks: sessionMouseClicks,
            mouseDistance: sessionMouseDistance,
            keystrokes: sessionKeystrokes,
            typingSpeed: getCurrentTypingSpeed(),
            scrollEvents: sessionScrollEvents,
            idleTime: 0,
            focusScore: calculateFocusScore(),
            appSwitchCount: appSwitchCount
        )
    }

    private func calculateFocusScore() -> Double {
        guard let startTime = sessionStartTime else { return 0 }
        let duration = Date().timeIntervalSince(startTime)
        guard duration > 60 else { return 0.5 }

        var score = 1.0
        let switchRate = Double(appSwitchCount) / (duration / 60.0)
        if switchRate > 3 { score -= 0.3 }
        else if switchRate > 1 { score -= 0.15 }

        let activityRate = Double(sessionKeystrokes + sessionMouseClicks) / (duration / 60.0)
        if activityRate > 30 { score += 0.1 }

        return max(0, min(1, score))
    }

    private func updateDailyMetrics(with session: InputSession) {
        todayMetrics.totalMouseClicks += session.mouseClicks
        todayMetrics.totalMouseDistance += session.mouseDistance
        todayMetrics.totalKeystrokes += session.keystrokes
        todayMetrics.totalScrollEvents += session.scrollEvents
        todayMetrics.sessionCount += 1
        todayMetrics.totalActiveTime += session.duration

        if session.typingSpeed > 0 {
            let totalTypingTime = todayMetrics.averageTypingSpeed * Double(todayMetrics.sessionCount - 1)
            todayMetrics.averageTypingSpeed = (totalTypingTime + session.typingSpeed) / Double(todayMetrics.sessionCount)
        }

        let hour = Calendar.current.component(.hour, from: session.startTime)
        todayMetrics.activityByHour[hour, default: 0] += session.keystrokes + session.mouseClicks
    }
}

// MARK: - Supporting Types

public struct InputMonitorConfiguration: Codable, Sendable {
    public var trackMouse: Bool = true
    public var trackKeyboard: Bool = true
    public var minSessionDuration: TimeInterval = 60
    public var idleTimeout: TimeInterval = 120
    public var sampleInterval: TimeInterval = 5
    public var maxRetainedSessions: Int = 100
    public init() {}
}

public struct InputSession: Sendable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let appBundleId: String
    public let mouseClicks: Int
    public let mouseDistance: Double
    public let keystrokes: Int
    public let typingSpeed: Double
    public let scrollEvents: Int
    public let idleTime: TimeInterval
    public let focusScore: Double
    public let appSwitchCount: Int
    public var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
}

public struct TypingBurst: Sendable {
    public var startTime: Date
    public var endTime: Date
    public var keystrokeCount: Int
    public var wordCount: Int
    public var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
}

public struct DailyInputMetrics: Sendable {
    public var date: Date = Date()
    public var totalMouseClicks: Int = 0
    public var totalMouseDistance: Double = 0
    public var totalKeystrokes: Int = 0
    public var totalScrollEvents: Int = 0
    public var sessionCount: Int = 0
    public var totalActiveTime: TimeInterval = 0
    public var averageTypingSpeed: Double = 0
    public var activityByHour: [Int: Int] = [:]
    public var peakProductivityHour: Int? { activityByHour.max(by: { $0.value < $1.value })?.key }
}
