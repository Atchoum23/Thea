/**
 * SmartDNS Monitor Service
 *
 * Runs on Mac to monitor IP changes and automatically handle SmartDNS re-activation.
 *
 * Features:
 * - Monitors public IP address changes
 * - Shows macOS notification when IP changes
 * - Automatically opens NordVPN SmartDNS activation page
 * - Syncs status with Thea-Tizen via sync-bridge
 * - Offers to enable monitoring on first launch
 */

import Foundation
import UserNotifications
import AppKit

@MainActor
public final class SmartDNSMonitorService: ObservableObject {
    public static let shared = SmartDNSMonitorService()

    // MARK: - Published State
    @Published public private(set) var currentIP: String?
    @Published public private(set) var activatedIP: String?
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var needsReactivation: Bool = false
    @Published public private(set) var lastCheckTime: Date?

    // MARK: - Configuration
    private let smartDNSActivationURL = URL(string: "https://my.nordaccount.com/dashboard/nordvpn/smartdns/")!
    private let checkInterval: TimeInterval = 60 // Check every minute
    private var monitorTask: Task<Void, Never>?

    // UserDefaults keys
    private let kActivatedIP = "smartDNS.activatedIP"
    private let kMonitoringEnabled = "smartDNS.monitoringEnabled"
    private let kLastKnownIP = "smartDNS.lastKnownIP"
    private let kSmartDNSPrimary = "smartDNS.primary"
    private let kSmartDNSSecondary = "smartDNS.secondary"

    // MARK: - SmartDNS Configuration
    public struct SmartDNSConfig {
        public var primary: String
        public var secondary: String
        public var activatedIP: String?

        public static let `default` = SmartDNSConfig(
            primary: "103.86.96.103",
            secondary: "103.86.99.103",
            activatedIP: "85.5.146.251"
        )
    }

    public private(set) var config: SmartDNSConfig

    // MARK: - Init
    private init() {
        // Load saved configuration
        let defaults = UserDefaults.standard
        self.config = SmartDNSConfig(
            primary: defaults.string(forKey: kSmartDNSPrimary) ?? SmartDNSConfig.default.primary,
            secondary: defaults.string(forKey: kSmartDNSSecondary) ?? SmartDNSConfig.default.secondary,
            activatedIP: defaults.string(forKey: kActivatedIP) ?? SmartDNSConfig.default.activatedIP
        )
        self.activatedIP = config.activatedIP
        self.currentIP = defaults.string(forKey: kLastKnownIP)

        // Check if monitoring was enabled
        if defaults.bool(forKey: kMonitoringEnabled) {
            startMonitoring()
        }

        // Request notification permissions
        requestNotificationPermission()
    }

    // MARK: - Public API

    /// Start monitoring IP changes
    public func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        UserDefaults.standard.set(true, forKey: kMonitoringEnabled)

        monitorTask = Task {
            await monitorLoop()
        }

        print("🌐 SmartDNS Monitor: Started")
    }

    /// Stop monitoring IP changes
    public func stopMonitoring() {
        isMonitoring = false
        UserDefaults.standard.set(false, forKey: kMonitoringEnabled)
        monitorTask?.cancel()
        monitorTask = nil

        print("🌐 SmartDNS Monitor: Stopped")
    }

    /// Update SmartDNS configuration (after receiving new config from NordVPN)
    public func updateConfig(primary: String, secondary: String, activatedIP: String) {
        let defaults = UserDefaults.standard
        defaults.set(primary, forKey: kSmartDNSPrimary)
        defaults.set(secondary, forKey: kSmartDNSSecondary)
        defaults.set(activatedIP, forKey: kActivatedIP)

        self.config = SmartDNSConfig(primary: primary, secondary: secondary, activatedIP: activatedIP)
        self.activatedIP = activatedIP
        self.needsReactivation = (currentIP != activatedIP)

        print("🌐 SmartDNS Config updated: \(primary) / \(secondary) for IP \(activatedIP)")
    }

    /// Manually trigger IP check
    public func checkNow() async {
        await checkIP()
    }

    /// Open SmartDNS activation page
    public func openActivationPage() {
        NSWorkspace.shared.open(smartDNSActivationURL)
    }

    /// Called after user activates SmartDNS - updates the activated IP
    public func confirmActivation() {
        guard let currentIP = currentIP else { return }

        updateConfig(
            primary: config.primary,
            secondary: config.secondary,
            activatedIP: currentIP
        )

        needsReactivation = false
        showNotification(
            title: "SmartDNS Activated",
            body: "SmartDNS is now active for IP: \(currentIP)"
        )
    }

    // MARK: - Private

    private func monitorLoop() async {
        while !Task.isCancelled && isMonitoring {
            await checkIP()
            try? await Task.sleep(for: .seconds(checkInterval))
        }
    }

    private func checkIP() async {
        do {
            let ip = try await fetchPublicIP()
            let previousIP = currentIP

            await MainActor.run {
                self.currentIP = ip
                self.lastCheckTime = Date()
                UserDefaults.standard.set(ip, forKey: kLastKnownIP)
            }

            // Check if IP changed
            if let previousIP = previousIP, previousIP != ip {
                await handleIPChange(from: previousIP, to: ip)
            }

            // Check if current IP matches activated IP
            await MainActor.run {
                self.needsReactivation = (self.activatedIP != nil && self.activatedIP != ip)
            }

        } catch {
            print("🌐 SmartDNS Monitor: Failed to fetch IP - \(error)")
        }
    }

    private func fetchPublicIP() async throws -> String {
        // Use ipv4.icanhazip.com to ensure we always get IPv4 address
        // (SmartDNS is tied to IPv4, not IPv6)
        let url = URL(string: "https://ipv4.icanhazip.com/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw NSError(domain: "SmartDNS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid IP response"])
        }
        return ip
    }

    private func handleIPChange(from previousIP: String, to currentIP: String) async {
        print("🌐 IP CHANGED: \(previousIP) → \(currentIP)")

        // Check if this affects SmartDNS
        guard let activatedIP = activatedIP, activatedIP == previousIP else {
            // IP changed but SmartDNS wasn't activated for the old IP
            return
        }

        await MainActor.run {
            self.needsReactivation = true
        }

        // Show notification
        showNotification(
            title: "SmartDNS Re-activation Required",
            body: "Your IP changed to \(currentIP). Click to open activation page.",
            actionURL: smartDNSActivationURL
        )

        // Automatically open the activation page
        await MainActor.run {
            openActivationPage()
        }

        // Sync with Thea-Tizen via sync-bridge (if configured)
        await notifyTizenApp(previousIP: previousIP, currentIP: currentIP)
    }

    private func notifyTizenApp(previousIP: String, currentIP: String) async {
        // Notify Tizen companion app via sync-bridge using Bonjour/mDNS
        // The Tizen app listens on port 8765 for JSON notifications
        let payload: [String: Any] = [
            "type": "smartdns_ip_change",
            "previousIP": previousIP,
            "currentIP": currentIP,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        // Try to reach the Tizen sync-bridge endpoint
        let tizenHost = UserDefaults.standard.string(forKey: "tizen.syncBridgeHost") ?? ""
        guard !tizenHost.isEmpty,
              let url = URL(string: "http://\(tizenHost):8765/notify")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("🌐 SmartDNS Monitor: Tizen app notified of IP change")
            }
        } catch {
            // Tizen app not reachable — this is expected when TV is off
            print("🌐 SmartDNS Monitor: Tizen app not reachable (\(error.localizedDescription))")
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("🌐 SmartDNS Monitor: Notification permission granted")
            }
        }
    }

    private func showNotification(title: String, body: String, actionURL: URL? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let url = actionURL {
            content.userInfo = ["actionURL": url.absoluteString]
        }

        let request = UNNotificationRequest(
            identifier: "smartdns-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

public struct SmartDNSStatusView: View {
    @ObservedObject var monitor = SmartDNSMonitorService.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text("SmartDNS")
                    .font(.headline)

                Spacer()

                if monitor.isMonitoring {
                    Text("Monitoring")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Current IP
            if let ip = monitor.currentIP {
                HStack {
                    Text("Current IP:")
                        .foregroundColor(.secondary)
                    Text(ip)
                        .fontDesign(.monospaced)
                }
                .font(.caption)
            }

            // Activated IP
            if let activatedIP = monitor.activatedIP {
                HStack {
                    Text("Activated for:")
                        .foregroundColor(.secondary)
                    Text(activatedIP)
                        .fontDesign(.monospaced)
                }
                .font(.caption)
            }

            // Status message
            if monitor.needsReactivation {
                Text("⚠️ IP changed - SmartDNS needs re-activation")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Actions
            HStack {
                if monitor.needsReactivation {
                    Button("Re-activate") {
                        monitor.openActivationPage()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("I've Activated") {
                        monitor.confirmActivation()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Toggle("Monitor IP", isOn: Binding(
                        get: { monitor.isMonitoring },
                        set: { $0 ? monitor.startMonitoring() : monitor.stopMonitoring() }
                    ))
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        if monitor.needsReactivation {
            return .orange
        } else if monitor.isMonitoring && monitor.currentIP == monitor.activatedIP {
            return .green
        } else if monitor.isMonitoring {
            return .yellow
        } else {
            return .gray
        }
    }
}
#endif
