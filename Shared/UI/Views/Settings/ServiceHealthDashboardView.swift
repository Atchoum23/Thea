// ServiceHealthDashboardView.swift
// Thea — Real-time service health dashboard
//
// Shows status of all Thea services grouped by category.
// Recovery history, system uptime, health percentage.

import SwiftUI

struct ServiceHealthDashboardView: View {
    @StateObject private var monitor = BackgroundServiceMonitor.shared
    @State private var showRecoveryHistory = false
    @State private var isRefreshing = false

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - macOS Layout

    #if os(macOS)
    private var macOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                overviewCards
                serviceGroups
                recoverySection
            }
            .padding()
        }
        .navigationTitle("Service Health")
    }
    #endif

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSLayout: some View {
        List {
            headerListSection
            serviceListGroups
            recoveryListSection
        }
        .navigationTitle("Service Health")
        .refreshable {
            await monitor.performHealthCheck()
        }
    }
    #endif

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Overall status indicator
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: monitor.latestSnapshot?.overallStatus.icon ?? "questionmark.circle")
                        .font(.title2)
                        .foregroundStyle(statusColor(for: monitor.latestSnapshot?.overallStatus ?? .unknown))

                    Text(overallStatusText)
                        .font(.headline)
                }

                if let lastCheck = monitor.lastCheckTime {
                    Text("Last check: \(lastCheck, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Refresh button
            Button {
                isRefreshing = true
                Task {
                    await monitor.performHealthCheck()
                    isRefreshing = false
                }
            } label: {
                Label("Check Now", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)

            // Monitoring toggle
            Toggle(isOn: Binding(
                get: { monitor.isMonitoring },
                set: { newValue in
                    if newValue {
                        monitor.startMonitoring()
                    } else {
                        monitor.stopMonitoring()
                    }
                }
            )) {
                Text("Auto-Monitor")
            }
            .toggleStyle(.switch)
            .accessibilityLabel("Toggle automatic health monitoring")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }

    #if os(iOS)
    private var headerListSection: some View {
        Section {
            HStack {
                Image(systemName: monitor.latestSnapshot?.overallStatus.icon ?? "questionmark.circle")
                    .foregroundStyle(statusColor(for: monitor.latestSnapshot?.overallStatus ?? .unknown))
                Text(overallStatusText)
                Spacer()
                Text(String(format: "%.0f%%", monitor.healthyPercentage))
                    .font(.headline)
                    .foregroundStyle(monitor.healthyPercentage >= 80 ? .green : .orange)
            }

            Toggle("Auto-Monitor", isOn: Binding(
                get: { monitor.isMonitoring },
                set: { newValue in
                    if newValue {
                        monitor.startMonitoring()
                    } else {
                        monitor.stopMonitoring()
                    }
                }
            ))

            if let lastCheck = monitor.lastCheckTime {
                HStack {
                    Text("Last check")
                    Spacer()
                    Text(lastCheck, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Uptime")
                Spacer()
                Text(monitor.uptimeString)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Overview")
        }
    }
    #endif

    // MARK: - Overview Cards (macOS)

    private var overviewCards: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Health",
                value: String(format: "%.0f%%", monitor.healthyPercentage),
                icon: "heart.fill",
                color: monitor.healthyPercentage >= 80 ? .green : (monitor.healthyPercentage >= 50 ? .orange : .red)
            )

            statCard(
                title: "Services",
                value: "\(monitor.latestSnapshot?.checks.count ?? 0)",
                icon: "square.grid.2x2",
                color: .blue
            )

            statCard(
                title: "Recoveries",
                value: "\(monitor.recoveryHistory.count)",
                icon: "arrow.triangle.2.circlepath",
                color: .purple
            )

            statCard(
                title: "Uptime",
                value: monitor.uptimeString,
                icon: "clock",
                color: .secondary
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
    }

    // MARK: - Service Groups

    private var serviceGroups: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(TheaServiceCategory.allCases, id: \.self) { category in
                let checks = monitor.servicesByCategory[category] ?? []
                if !checks.isEmpty {
                    serviceCategorySection(category: category, checks: checks)
                }
            }
        }
    }

    #if os(iOS)
    private var serviceListGroups: some View {
        ForEach(TheaServiceCategory.allCases, id: \.self) { category in
            let checks = monitor.servicesByCategory[category] ?? []
            if !checks.isEmpty {
                Section {
                    ForEach(checks) { check in
                        serviceListRow(check: check)
                    }
                } header: {
                    Label(category.displayName, systemImage: category.icon)
                }
            }
        }
    }
    #endif

    private func serviceCategorySection(category: TheaServiceCategory, checks: [TheaServiceCheckResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(category.displayName, systemImage: category.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(checks) { check in
                    serviceRow(check: check)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
        }
    }

    private func serviceRow(check: TheaServiceCheckResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: check.status.icon)
                .foregroundStyle(statusColor(for: check.status))
                .frame(width: 20)
                .accessibilityLabel("Status: \(check.status.rawValue)")

            VStack(alignment: .leading, spacing: 2) {
                Text(check.serviceName)
                    .font(.body)

                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let latency = check.latencyMs {
                Text(String(format: "%.0fms", latency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if check.recoveryAttempted {
                Image(systemName: check.recoverySucceeded == true ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(check.recoverySucceeded == true ? .green : .red)
                    .font(.caption)
                    .accessibilityLabel("Recovery \(check.recoverySucceeded == true ? "succeeded" : "failed")")
            }

            if let failures = monitor.consecutiveFailures[check.serviceID], failures > 0 {
                Text("\(failures)x")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.red.opacity(0.15)))
            }
        }
        .padding(.vertical, 4)
    }

    #if os(iOS)
    private func serviceListRow(check: TheaServiceCheckResult) -> some View {
        HStack {
            Image(systemName: check.status.icon)
                .foregroundStyle(statusColor(for: check.status))

            VStack(alignment: .leading) {
                Text(check.serviceName)
                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let failures = monitor.consecutiveFailures[check.serviceID], failures > 0 {
                Text("\(failures)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.red))
            }
        }
    }
    #endif

    // MARK: - Recovery History

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recovery History")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if monitor.recoveryHistory.count > 5 {
                    Button(showRecoveryHistory ? "Show Less" : "Show All") {
                        showRecoveryHistory.toggle()
                    }
                    .font(.caption)
                }
            }

            let items = showRecoveryHistory
                ? monitor.recoveryHistory
                : Array(monitor.recentRecoveries.prefix(5))

            if items.isEmpty {
                Text("No recovery actions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(items) { action in
                        HStack(spacing: 8) {
                            Image(systemName: action.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(action.succeeded ? .green : .red)
                                .font(.caption)

                            Text(action.actionName)
                                .font(.caption)

                            Text("(\(action.serviceID))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(action.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
            }
        }
    }

    #if os(iOS)
    private var recoveryListSection: some View {
        Section {
            if monitor.recoveryHistory.isEmpty {
                Text("No recovery actions yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(monitor.recentRecoveries) { action in
                    HStack {
                        Image(systemName: action.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(action.succeeded ? .green : .red)

                        VStack(alignment: .leading) {
                            Text(action.actionName)
                            if let error = action.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(action.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Recovery History")
        }
    }
    #endif

    // MARK: - Helpers

    private var overallStatusText: String {
        guard let snapshot = monitor.latestSnapshot else {
            return "No data — run a health check"
        }
        switch snapshot.overallStatus {
        case .healthy:
            return "All Services Healthy"
        case .degraded:
            return "\(snapshot.degradedCount + snapshot.recoveryCount) service(s) need attention"
        case .unhealthy:
            return "\(snapshot.unhealthyCount) service(s) unhealthy"
        case .unknown:
            return "Status unknown"
        case .recovering:
            return "Recovery in progress"
        }
    }

    private func statusColor(for status: TheaServiceStatus) -> Color {
        switch status {
        case .healthy: .green
        case .degraded: .orange
        case .unhealthy: .red
        case .unknown: .secondary
        case .recovering: .blue
        }
    }
}
