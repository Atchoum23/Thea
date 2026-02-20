// ServerHealthMonitor.swift
// Thea — AP3: MSM3U Reliability Infrastructure
//
// Monitors primary server (MSM3U:18789) reachability via NWConnection.
// On N consecutive failures (threshold from PersonalParameters), triggers
// OS-level failover script (macOS) and sends ntfy alert (all platforms).
// On recovery, cancels failover and notifies.
//
// Actor-isolated: reads PersonalParameters via await MainActor.run{}
// so it never touches the @MainActor singleton from a non-main context.

import Foundation
import Network
import OSLog
import UserNotifications

// MARK: - ServerHealthMonitor

actor ServerHealthMonitor {
    static let shared = ServerHealthMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ServerHealthMonitor")

    // MARK: - State

    private var consecutiveFailures = 0
    private var isFailoverActive = false
    private var monitorTask: Task<Void, Never>?

    // MARK: - Dynamic thresholds via PersonalParameters (SelfTuningEngine adapts these)

    private var failoverThreshold: Int {
        get async { await MainActor.run { PersonalParameters.shared.serverFailoverThreshold } }
    }

    private var pollIntervalSec: Int {
        get async { await MainActor.run { PersonalParameters.shared.serverPollIntervalSeconds } }
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task {
            logger.info("ServerHealthMonitor: started — polling msm3u.local:18789")
            while !Task.isCancelled {
                await checkHealth()
                let interval = await pollIntervalSec
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        logger.info("ServerHealthMonitor: stopped")
    }

    // MARK: - Health Check

    private func checkHealth() async {
        let threshold = await failoverThreshold
        let reachable = await canConnect(host: "msm3u.local", port: 18789)

        if reachable {
            if isFailoverActive {
                isFailoverActive = false
                consecutiveFailures = 0
                logger.info("ServerHealthMonitor: MSM3U back online — cancelling failover")
                await notify(title: "MSM3U Back Online", body: "Failover cancelled — primary server restored.", priority: "default")
            } else if consecutiveFailures > 0 {
                consecutiveFailures = 0
                logger.info("ServerHealthMonitor: MSM3U recovered after \(threshold - 1) failures")
            }
        } else {
            consecutiveFailures += 1
            logger.warning("ServerHealthMonitor: failure \(self.consecutiveFailures)/\(threshold)")

            if consecutiveFailures >= threshold && !isFailoverActive {
                isFailoverActive = true
                logger.error("ServerHealthMonitor: \(threshold) failures — triggering failover")
                #if os(macOS)
                triggerFailoverScript()
                #endif
                await notify(
                    title: "MSM3U Offline",
                    body: "\(threshold) consecutive failures. MBAM2 failover initiated.",
                    priority: "high"
                )
            }
        }
    }

    // MARK: - Network Connectivity Check

    /// TCP connect attempt to host:port with 5s timeout.
    private func canConnect(host: String, port: UInt16) async -> Bool {
        /// One-shot gate: protects continuation from being resumed twice across concurrent closures.
        final class OnceGate: @unchecked Sendable {
            private let lock = NSLock()
            private var fired = false
            func fire(_ block: () -> Void) {
                lock.withLock {
                    guard !fired else { return }
                    fired = true
                    block()
                }
            }
        }

        return await withCheckedContinuation { continuation in
            let gate = OnceGate()

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            connection.stateUpdateHandler = { [weak connection] state in
                switch state {
                case .ready:
                    gate.fire { continuation.resume(returning: true) }
                    connection?.cancel()
                case .failed, .waiting:
                    gate.fire { continuation.resume(returning: false) }
                    connection?.cancel()
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // 5-second hard timeout
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { [weak connection] in
                gate.fire { continuation.resume(returning: false) }
                connection?.cancel()
            }
        }
    }

    // MARK: - Failover Script (macOS)

    #if os(macOS)
    private func triggerFailoverScript() {
        let scriptURL = URL(fileURLWithPath: "/Users/alexis/bin/msm3u-failover.sh")
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            logger.warning("ServerHealthMonitor: failover script not found at \(scriptURL.path)")
            return
        }
        let process = Process()
        process.executableURL = scriptURL
        process.arguments = []
        do {
            try process.run()
            logger.info("ServerHealthMonitor: msm3u-failover.sh launched")
        } catch {
            logger.error("ServerHealthMonitor: failed to run failover script — \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Notification (ntfy)

    private func notify(title: String, body: String, priority: String) async {
        // ntfy push (works even when app is background or closed)
        guard let url = URL(string: "https://ntfy.sh/thea-msm3u") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(priority, forHTTPHeaderField: "Priority")
        request.httpBody = body.data(using: .utf8)
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("ServerHealthMonitor: ntfy notification failed — \(error.localizedDescription)")
        }

        // In-app notification (works when app is foreground)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = priority == "high" ? .defaultCritical : .default
        let notifRequest = UNNotificationRequest(
            identifier: "server-health-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(notifRequest)
        } catch {
            logger.error("ServerHealthMonitor: UNNotification failed — \(error.localizedDescription)")
        }
    }
}
