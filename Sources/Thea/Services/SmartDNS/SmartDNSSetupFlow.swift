/**
 * SmartDNS Setup Flow
 *
 * Presented automatically when Thea detects SmartDNS should be configured.
 * Guides the user through the setup process and offers to enable automatic
 * IP monitoring and re-activation.
 */

import SwiftUI

public struct SmartDNSSetupFlow: View {
    @StateObject private var monitor = SmartDNSMonitorService.shared
    @State private var currentStep: SetupStep = .welcome
    @State private var isLoading = false

    @Environment(\.dismiss) private var dismiss

    enum SetupStep {
        case welcome
        case checkingIP
        case configureSmartDNS
        case enableMonitoring
        case complete
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                content
                    .padding(24)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 500, height: 450)
        .onAppear {
            Task {
                await checkCurrentIP()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "network")
                .font(.title)
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text("SmartDNS Setup")
                    .font(.headline)
                Text("Configure automatic geo-unblocking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Step indicator
            Text(stepIndicator)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var stepIndicator: String {
        switch currentStep {
        case .welcome: return "Step 1 of 4"
        case .checkingIP: return "Step 2 of 4"
        case .configureSmartDNS: return "Step 3 of 4"
        case .enableMonitoring: return "Step 4 of 4"
        case .complete: return "Complete"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch currentStep {
        case .welcome:
            welcomeContent
        case .checkingIP:
            checkingIPContent
        case .configureSmartDNS:
            configureSmartDNSContent
        case .enableMonitoring:
            enableMonitoringContent
        case .complete:
            completeContent
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Access Content from Anywhere")
                .font(.title2)
                .fontWeight(.semibold)

            Text("SmartDNS lets you access streaming content from different regions on your Samsung TV, without the slowdowns of a traditional VPN.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "play.tv", text: "Unblock Netflix US, BBC iPlayer, etc.")
                FeatureRow(icon: "bolt.fill", text: "No speed reduction - DNS only")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Automatic re-activation when IP changes")
            }
            .padding(.top)
        }
    }

    private var checkingIPContent: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Checking your IP address...")
                    .foregroundColor(.secondary)
            } else if let ip = monitor.currentIP {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)

                Text("Your IP Address")
                    .font(.headline)

                Text(ip)
                    .font(.system(.title, design: .monospaced))
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)

                if monitor.needsReactivation {
                    Label("SmartDNS is configured for a different IP", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private var configureSmartDNSContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Configure SmartDNS")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Thea will now open the NordVPN SmartDNS page. Please click \"Activate SmartDNS\" on that page.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your SmartDNS servers:")
                    .font(.headline)

                HStack {
                    Text("Primary:")
                        .foregroundColor(.secondary)
                    Text(monitor.config.primary)
                        .fontDesign(.monospaced)
                }

                HStack {
                    Text("Secondary:")
                        .foregroundColor(.secondary)
                    Text(monitor.config.secondary)
                        .fontDesign(.monospaced)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            Button("Open NordVPN SmartDNS Page") {
                monitor.openActivationPage()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var enableMonitoringContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Enable Automatic Monitoring")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Thea can monitor your IP address and automatically open the re-activation page when it changes. You'll just need to click \"Activate\".")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "network", text: "Checks your IP every minute")
                FeatureRow(icon: "bell", text: "Shows notification when IP changes")
                FeatureRow(icon: "safari", text: "Opens activation page automatically")
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var completeContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("SmartDNS is configured and monitoring is enabled. Thea will automatically help you re-activate SmartDNS whenever your IP changes.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current IP:")
                        .foregroundColor(.secondary)
                    Text(monitor.currentIP ?? "Unknown")
                        .fontDesign(.monospaced)
                }

                HStack {
                    Text("Monitoring:")
                        .foregroundColor(.secondary)
                    Text(monitor.isMonitoring ? "Enabled ✓" : "Disabled")
                        .foregroundColor(monitor.isMonitoring ? .green : .secondary)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if currentStep != .welcome && currentStep != .complete {
                Button("Back") {
                    goBack()
                }
            }

            Spacer()

            switch currentStep {
            case .welcome:
                Button("Get Started") {
                    goNext()
                }
                .buttonStyle(.borderedProminent)

            case .checkingIP:
                Button("Continue") {
                    goNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(monitor.currentIP == nil)

            case .configureSmartDNS:
                Button("I've Activated SmartDNS") {
                    confirmActivationAndContinue()
                }
                .buttonStyle(.borderedProminent)

            case .enableMonitoring:
                HStack {
                    Button("Skip") {
                        currentStep = .complete
                    }

                    Button("Enable Monitoring") {
                        enableMonitoringAndContinue()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .complete:
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func checkCurrentIP() async {
        isLoading = true
        await monitor.checkNow()
        isLoading = false
    }

    private func goNext() {
        withAnimation {
            switch currentStep {
            case .welcome:
                currentStep = .checkingIP
                Task {
                    await checkCurrentIP()
                }
            case .checkingIP:
                currentStep = .configureSmartDNS
            case .configureSmartDNS:
                currentStep = .enableMonitoring
            case .enableMonitoring:
                currentStep = .complete
            case .complete:
                dismiss()
            }
        }
    }

    private func goBack() {
        withAnimation {
            switch currentStep {
            case .checkingIP:
                currentStep = .welcome
            case .configureSmartDNS:
                currentStep = .checkingIP
            case .enableMonitoring:
                currentStep = .configureSmartDNS
            default:
                break
            }
        }
    }

    private func confirmActivationAndContinue() {
        monitor.confirmActivation()
        goNext()
    }

    private func enableMonitoringAndContinue() {
        monitor.startMonitoring()
        currentStep = .complete
    }
}

// MARK: - Helper Views

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    SmartDNSSetupFlow()
}
