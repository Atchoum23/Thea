// SecurityScannerView.swift
// Thea — Security scanning and privacy audit UI
// Replaces: Moonlock
//
// Full scan, category-specific scans, findings dashboard, history.

import SwiftUI

struct SecurityScannerView: View {
    @State private var lastReport: ScanReport?
    @State private var scanHistory: [ScanReport] = []
    @State private var isScanning = false
    @State private var selectedCategories = Set(ScanCategory.allCases)
    // periphery:ignore - Reserved: selectedFinding property — reserved for future feature activation
    @State private var selectedFinding: SystemSecurityFinding?
    // periphery:ignore - Reserved: showCategoryPicker property — reserved for future feature activation
    @State private var showCategoryPicker = false

    var body: some View {
        #if os(macOS)
        // periphery:ignore - Reserved: selectedFinding property reserved for future feature activation
        // periphery:ignore - Reserved: showCategoryPicker property reserved for future feature activation
        HSplitView {
            scanPanel
                .frame(minWidth: 280, idealWidth: 320)
            findingsPanel
                .frame(minWidth: 400)
        }
        .navigationTitle("Security Scanner")
        .task { await loadHistory() }
        #else
        NavigationStack {
            List {
                scanSection
                lastScanSummary
                findingsSection
            }
            .navigationTitle("Security Scanner")
            .task { await loadHistory() }
        }
        #endif
    }

    // MARK: - macOS Panels

    #if os(macOS)
    private var scanPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status badge
            HStack {
                if let report = lastReport {
                    Image(systemName: report.overallThreatLevel.icon)
                        .foregroundStyle(threatColor(report.overallThreatLevel))
                    Text(report.overallThreatLevel.rawValue)
                        .font(.headline)
                        .foregroundStyle(threatColor(report.overallThreatLevel))
                } else {
                    Image(systemName: "questionmark.shield")
                        .foregroundStyle(.secondary)
                    Text("Not Scanned")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            Divider()

            // Category toggles
            Text("Scan Categories")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(ScanCategory.allCases, id: \.self) { category in
                Toggle(isOn: Binding(
                    get: { selectedCategories.contains(category) },
                    set: { isOn in
                        if isOn { selectedCategories.insert(category) } else { selectedCategories.remove(category) }
                    }
                )) {
                    Label(category.rawValue, systemImage: category.icon)
                        .font(.subheadline)
                }
                .toggleStyle(.checkbox)
                .padding(.horizontal)
                .accessibilityLabel("Scan \(category.rawValue)")
            }

            Spacer()

            // Last scan info
            if let report = lastReport {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Scan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(report.filesScanned) files in \(String(format: "%.1f", report.scanDuration))s")
                        .font(.caption)
                    Text(report.completedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            // Scan button
            Button {
                Task { await runScan() }
            } label: {
                if isScanning {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Run Full Scan", systemImage: "shield.checkerboard")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning || selectedCategories.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.vertical)
    }

    private var findingsPanel: some View {
        Group {
            if let report = lastReport {
                if report.findings.isEmpty {
                    ContentUnavailableView(
                        "All Clear",
                        systemImage: "checkmark.shield.fill",
                        description: Text("No security issues found in \(report.filesScanned) files")
                    )
                } else {
                    findingsListView(report)
                }
            } else if scanHistory.isEmpty {
                ContentUnavailableView(
                    "No Scans Yet",
                    systemImage: "shield.lefthalf.filled",
                    description: Text("Run a security scan to check your system")
                )
            } else {
                scanHistoryView
            }
        }
    }
    #endif

    // MARK: - iOS Sections

    // periphery:ignore - Reserved: scanSection property — reserved for future feature activation
    private var scanSection: some View {
        Section {
            Button {
                // periphery:ignore - Reserved: scanSection property reserved for future feature activation
                Task { await runScan() }
            } label: {
                if isScanning {
                    HStack {
                        ProgressView()
                        Text("Scanning…")
                    }
                } else {
                    Label("Run Full Scan", systemImage: "shield.checkerboard")
                }
            }
            .disabled(isScanning)
        }
    }

    // periphery:ignore - Reserved: lastScanSummary property — reserved for future feature activation
    @ViewBuilder
    private var lastScanSummary: some View {
        if let report = lastReport {
            // periphery:ignore - Reserved: lastScanSummary property reserved for future feature activation
            Section("Last Scan") {
                HStack {
                    Image(systemName: report.overallThreatLevel.icon)
                        .foregroundStyle(threatColor(report.overallThreatLevel))
                    Text(report.overallThreatLevel.rawValue)
                        .font(.headline)
                    Spacer()
                    Text("\(report.findings.count) findings")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("\(report.filesScanned) files", systemImage: "doc")
                    Spacer()
                    Text(report.completedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                if report.criticalCount > 0 {
                    severityRow("Critical", count: report.criticalCount, color: .red)
                }
                if report.highCount > 0 {
                    severityRow("High", count: report.highCount, color: .orange)
                }
                if report.mediumCount > 0 {
                    severityRow("Medium", count: report.mediumCount, color: .yellow)
                }
                if report.lowCount > 0 {
                    severityRow("Low", count: report.lowCount, color: .green)
                }
            }
        }
    }

    // periphery:ignore - Reserved: findingsSection property — reserved for future feature activation
    @ViewBuilder
    private var findingsSection: some View {
        // periphery:ignore - Reserved: findingsSection property reserved for future feature activation
        if let report = lastReport, !report.findings.isEmpty {
            ForEach(ScanCategory.allCases, id: \.self) { category in
                let catFindings = report.findings.filter { $0.category == category }
                if !catFindings.isEmpty {
                    Section(category.rawValue) {
                        ForEach(catFindings) { finding in
                            findingRow(finding)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared Components

    private func findingsListView(_ report: ScanReport) -> some View {
        List {
            // Summary bar
            Section("Summary") {
                HStack(spacing: 16) {
                    if report.criticalCount > 0 { countBadge("Critical", count: report.criticalCount, color: .red) }
                    if report.highCount > 0 { countBadge("High", count: report.highCount, color: .orange) }
                    if report.mediumCount > 0 { countBadge("Medium", count: report.mediumCount, color: .yellow) }
                    if report.lowCount > 0 { countBadge("Low", count: report.lowCount, color: .green) }
                }
            }

            // Findings by category
            ForEach(ScanCategory.allCases, id: \.self) { category in
                let catFindings = report.findings.filter { $0.category == category }
                if !catFindings.isEmpty {
                    Section(category.rawValue) {
                        ForEach(catFindings) { finding in
                            findingRow(finding)
                        }
                    }
                }
            }
        }
    }

    private func findingRow(_ finding: SystemSecurityFinding) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: finding.threatLevel.icon)
                    .foregroundStyle(threatColor(finding.threatLevel))
                Text(finding.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text(finding.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let path = finding.filePath {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            HStack {
                Image(systemName: "lightbulb")
                    .font(.caption2)
                Text(finding.recommendation)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    // periphery:ignore - Reserved: severityRow(_:count:color:) instance method reserved for future feature activation
    private func severityRow(_ label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    private func countBadge(_ label: String, count: Int, color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var scanHistoryView: some View {
        Group {
            if scanHistory.isEmpty {
                ContentUnavailableView(
                    "No Scan History",
                    systemImage: "shield.slash",
                    description: Text("Run a security scan to see results here.")
                )
            } else {
                List(scanHistory.reversed()) { report in
                    HStack {
                        Image(systemName: report.overallThreatLevel.icon)
                            .foregroundStyle(threatColor(report.overallThreatLevel))
                        VStack(alignment: .leading) {
                            Text("\(report.findings.count) findings")
                                .font(.subheadline)
                            Text("\(report.filesScanned) files scanned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(report.completedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        lastReport = report
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func runScan() async {
        isScanning = true
        let categories = Array(selectedCategories)
        lastReport = await SystemSecurityScanner.shared.runFullScan(categories: categories)
        await loadHistory()
        isScanning = false
    }

    private func loadHistory() async {
        scanHistory = await SystemSecurityScanner.shared.getHistory()
        if lastReport == nil {
            lastReport = scanHistory.last
        }
    }

    // MARK: - Helpers

    private func threatColor(_ level: ThreatLevel) -> Color {
        switch level {
        case .clean: .green
        case .low: .blue
        case .medium: .yellow
        case .high: .orange
        case .critical: .red
        }
    }
}
