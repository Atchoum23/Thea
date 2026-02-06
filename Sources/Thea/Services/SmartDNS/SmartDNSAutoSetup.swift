/**
 * SmartDNS Auto Setup
 *
 * Automatically triggers SmartDNS setup when appropriate:
 * - On first launch (if SmartDNS config detected)
 * - When Thea-Tizen notifies of IP change
 * - When user hasn't set up monitoring yet
 */

import SwiftUI
import AppKit

@MainActor
public final class SmartDNSAutoSetup: ObservableObject {
    public static let shared = SmartDNSAutoSetup()

    @Published public var showingSetupFlow = false
    @Published public var showingReactivationAlert = false

    private let hasCompletedSetupKey = "smartDNS.hasCompletedSetup"
    private let monitor = SmartDNSMonitorService.shared

    private init() {
        // Check if setup needed on launch
        checkIfSetupNeeded()

        // Listen for IP changes that need attention
        setupIPChangeListener()
    }

    // MARK: - Public API

    /// Check if SmartDNS setup should be shown
    public func checkIfSetupNeeded() {
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: hasCompletedSetupKey)

        // Show setup if:
        // 1. Never completed setup AND SmartDNS credentials exist
        // 2. OR monitoring is not enabled but should be
        if !hasCompletedSetup && monitor.activatedIP != nil {
            // User has SmartDNS config but hasn't gone through setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.presentSetupFlow()
            }
        }
    }

    /// Present the setup flow
    public func presentSetupFlow() {
        showingSetupFlow = true
    }

    /// Mark setup as complete
    public func markSetupComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedSetupKey)
    }

    /// Reset setup state (for testing)
    public func resetSetupState() {
        UserDefaults.standard.set(false, forKey: hasCompletedSetupKey)
    }

    /// Handle IP change notification from Tizen
    public func handleIPChangeFromTizen(previousIP: String, currentIP: String) {
        // Show reactivation alert and open page
        showingReactivationAlert = true
        monitor.openActivationPage()
    }

    // MARK: - Private

    private func setupIPChangeListener() {
        // This would be connected to sync-bridge notifications
        // For now, the SmartDNSMonitorService handles IP changes directly
    }
}

// MARK: - App Integration

/// Add this to your main App struct
public struct SmartDNSSetupModifier: ViewModifier {
    @ObservedObject var autoSetup = SmartDNSAutoSetup.shared

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $autoSetup.showingSetupFlow) {
                SmartDNSSetupFlow()
                    .onDisappear {
                        autoSetup.markSetupComplete()
                    }
            }
            .alert("SmartDNS Re-activation Required", isPresented: $autoSetup.showingReactivationAlert) {
                Button("Open Activation Page") {
                    SmartDNSMonitorService.shared.openActivationPage()
                }
                Button("I've Already Activated") {
                    SmartDNSMonitorService.shared.confirmActivation()
                }
                Button("Later", role: .cancel) {}
            } message: {
                Text("Your IP address has changed. SmartDNS needs to be re-activated to continue working.")
            }
    }
}

public extension View {
    /// Add SmartDNS setup flow to the app
    func withSmartDNSSetup() -> some View {
        modifier(SmartDNSSetupModifier())
    }
}

// MARK: - Menu Bar Integration (optional)

/// A menu bar extra for quick SmartDNS status
public struct SmartDNSMenuBarView: View {
    @ObservedObject var monitor = SmartDNSMonitorService.shared
    @ObservedObject var autoSetup = SmartDNSAutoSetup.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.headline)
            }

            Divider()

            // Current IP
            if let ip = monitor.currentIP {
                Text("IP: \(ip)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Last check
            if let lastCheck = monitor.lastCheckTime {
                Text("Last check: \(lastCheck.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Actions
            if monitor.needsReactivation {
                Button("Re-activate SmartDNS") {
                    monitor.openActivationPage()
                }

                Button("I've Activated") {
                    monitor.confirmActivation()
                }
            }

            Button(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    monitor.startMonitoring()
                }
            }

            Divider()

            Button("SmartDNS Settings...") {
                autoSetup.presentSetupFlow()
            }
        }
        .padding(8)
        .frame(width: 200)
    }

    private var statusColor: Color {
        if monitor.needsReactivation {
            return .orange
        } else if monitor.isMonitoring {
            return .green
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if monitor.needsReactivation {
            return "Needs Re-activation"
        } else if monitor.isMonitoring {
            return "SmartDNS Active"
        } else {
            return "SmartDNS Inactive"
        }
    }
}
