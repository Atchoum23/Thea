// AutonomousSettingsViewSections.swift
// Helper views for AutonomousSettingsView

import SwiftUI

// MARK: - Resource Bar

struct ResourceBar: View {
    let label: String
    let icon: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(color)

            Text(label)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * value, height: 6)
                }
            }
            .frame(width: 100, height: 6)

            Text("\(Int(value * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Autonomous Stat Row

struct AutonomousStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Consent Request View

struct ConsentRequestView: View {
    @Binding var isPresented: Bool
    @State private var governor = AIModelGovernor.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Enable Autonomous Intelligence")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Let Thea proactively optimize your AI experience")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    Divider()

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        AutonomousFeatureRow(
                            icon: "arrow.down.circle",
                            title: "Smart Model Downloads",
                            description: "Automatically download optimal models for your tasks based on AI analysis"
                        )

                        AutonomousFeatureRow(
                            icon: "trash.circle",
                            title: "Intelligent Cleanup",
                            description: "Remove low-value models based on actual usage, not arbitrary time limits"
                        )

                        AutonomousFeatureRow(
                            icon: "gauge.high",
                            title: "Dynamic Resources",
                            description: "AI-optimized GPU, CPU, and memory allocation based on current workload"
                        )

                        AutonomousFeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Continuous Learning",
                            description: "Proactivity increases over time based on your feedback"
                        )
                    }
                    .padding(.horizontal)

                    Divider()

                    // Privacy Note
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacy & Control", systemImage: "lock.shield")
                            .font(.headline)

                        Text("• All decisions are made locally on your device\n• You can override any action\n• Revoke consent at any time in Settings\n• No data is sent externally")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enable") {
                        governor.hasAutonomousConsent = true
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

// MARK: - Feature Row

struct AutonomousFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Proactivity Details View

struct ProactivityDetailsView: View {
    @State private var governor = AIModelGovernor.shared

    private var recentEvents: [ProactivityEvent] {
        Array(governor.proactivityHistory.suffix(20).reversed())
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Recent Actions") {
                    ForEach(Array(recentEvents.enumerated()), id: \.offset) { _, event in
                        HStack {
                            Image(systemName: event.wasHelpful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(event.wasHelpful ? .green : .red)

                            VStack(alignment: .leading) {
                                Text(event.action)
                                    .font(.subheadline)
                                Text(event.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if event.userOverrode {
                                Text("Overridden")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Proactivity History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Resource Monitor View

struct ResourceMonitorView: View {
    @State private var governor = AIModelGovernor.shared
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                Section("Current Allocation") {
                    let allocation = governor.getOptimalResourceAllocation()

                    ResourceBar(label: "GPU", icon: "gpu", value: allocation.gpuPercentage, color: .green)
                    ResourceBar(label: "CPU", icon: "cpu", value: allocation.cpuPercentage, color: .blue)
                    ResourceBar(label: "Memory", icon: "memorychip", value: allocation.memoryPercentage, color: .orange)

                    Text(allocation.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("System State") {
                    HStack {
                        Text("Thermal State")
                        Spacer()
                        Text(governor.systemState.thermalState.rawValue.capitalized)
                            .foregroundStyle(thermalColor(governor.systemState.thermalState))
                    }

                    HStack {
                        Text("Active Inferences")
                        Spacer()
                        Text("\(governor.systemState.activeInferenceCount)")
                    }

                    HStack {
                        Text("Pending Tasks")
                        Spacer()
                        Text("\(governor.systemState.pendingTasks)")
                    }
                }
            }
            .navigationTitle("Resource Monitor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onReceive(timer) { _ in
                // Refresh view
            }
        }
    }

    private func thermalColor(_ state: GovernorThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AutonomousSettingsView()
    }
}
