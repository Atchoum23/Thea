// SystemCleanerView.swift
// Thea — Disk cleanup UI
// Replaces: CleanMyMac

import SwiftUI

struct SystemCleanerView: View {
    @State private var cleaner = SystemCleaner.shared
    @State private var selectedCategories: Set<CleanableCategory> = Set(CleanableCategory.allCases.filter { $0.safetyLevel == .safe })
    @State private var showCleanConfirmation = false
    @State private var lastCleanResult: CleanupResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                diskOverview
                scanSection
                if let scanResult = cleaner.lastScanResult {
                    categoryList(scanResult)
                    cleanButton(scanResult)
                }
                if let result = lastCleanResult {
                    cleanupResultBanner(result)
                }
                historySection
            }
            .padding()
        }
        .navigationTitle("System Cleaner")
    }

    // MARK: - Disk Overview

    private var diskOverview: some View {
        GroupBox("Disk Usage") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(cleaner.formattedAvailableSpace)
                            .font(.title2.bold())
                        Text("Available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(cleaner.formattedTotalSpace)
                            .font(.title2.bold())
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: cleaner.diskUsagePercent, total: 100)
                    .tint(diskUsageColor)

                HStack {
                    Label(String(format: "%.0f%% used", cleaner.diskUsagePercent), systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if cleaner.totalBytesFreed > 0 {
                        Label("\(cleaner.formattedTotalFreed) freed total", systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var diskUsageColor: Color {
        if cleaner.diskUsagePercent > 90 { return .red }
        if cleaner.diskUsagePercent > 75 { return .orange }
        return .blue
    }

    // MARK: - Scan Section

    private var scanSection: some View {
        GroupBox {
            HStack {
                if cleaner.isScanning {
                    ProgressView(value: cleaner.scanProgress)
                        .frame(maxWidth: .infinity)
                    Text(String(format: "%.0f%%", cleaner.scanProgress * 100))
                        .font(.caption)
                        .monospacedDigit()
                } else {
                    Text(cleaner.lastScanResult == nil ? "Scan your system to find cleanable files" : "Scan complete")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Button(action: {
                    Task { await cleaner.scan() }
                }) {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(cleaner.isScanning || cleaner.isCleaning)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Category List

    private func categoryList(_ scanResult: ScanResult) -> some View {
        GroupBox("Found Items") {
            VStack(spacing: 0) {
                ForEach(CleanableCategory.allCases) { category in
                    let size = scanResult.categoryBreakdown[category] ?? 0
                    if size > 0 {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedCategories.contains(category) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedCategories.insert(category)
                                    } else {
                                        selectedCategories.remove(category)
                                    }
                                }
                            )) {
                                HStack {
                                    Image(systemName: category.icon)
                                        .frame(width: 20)
                                        .foregroundStyle(safetyColor(category.safetyLevel))
                                    VStack(alignment: .leading) {
                                        Text(category.rawValue)
                                            .font(.body)
                                        Text(category.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)

                            Spacer()

                            Text(SystemCleaner.formatBytes(size))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)

                            safetyBadge(category.safetyLevel)
                        }
                        .padding(.vertical, 6)

                        if category != CleanableCategory.allCases.last {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func safetyBadge(_ level: SafetyLevel) -> some View {
        Text(level.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(safetyColor(level).opacity(0.15))
            .foregroundStyle(safetyColor(level))
            .clipShape(Capsule())
    }

    private func safetyColor(_ level: SafetyLevel) -> Color {
        switch level {
        case .safe: .green
        case .caution: .orange
        case .warning: .red
        }
    }

    // MARK: - Clean Button

    private func cleanButton(_ scanResult: ScanResult) -> some View {
        let selectedSize = selectedCategories.reduce(0 as UInt64) { total, category in
            total + (scanResult.categoryBreakdown[category] ?? 0)
        }

        return Button(action: { showCleanConfirmation = true }) {
            HStack {
                Image(systemName: "trash")
                Text("Clean \(SystemCleaner.formatBytes(selectedSize))")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(selectedCategories.isEmpty || cleaner.isCleaning)
        .confirmationDialog("Clean selected categories?", isPresented: $showCleanConfirmation) {
            Button("Clean \(SystemCleaner.formatBytes(selectedSize))", role: .destructive) {
                Task {
                    let result = await cleaner.clean(categories: selectedCategories)
                    lastCleanResult = result
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(SystemCleaner.formatBytes(selectedSize)) of cached and temporary files. This action cannot be undone.")
        }
    }

    // MARK: - Cleanup Result

    private func cleanupResultBanner(_ result: CleanupResult) -> some View {
        GroupBox {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("\(result.formattedBytesFreed) freed")
                        .font(.headline)
                    Text("\(result.filesDeleted) items deleted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !result.errors.isEmpty {
                    Label("\(result.errors.count) errors", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - History

    private var historySection: some View {
        Group {
            if !cleaner.cleanupHistory.isEmpty {
                GroupBox("Cleanup History") {
                    VStack(spacing: 0) {
                        ForEach(cleaner.cleanupHistory.prefix(10)) { result in
                            HStack {
                                Text(result.timestamp, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(result.formattedBytesFreed)
                                    .font(.caption.monospacedDigit())
                                Text("\(result.filesDeleted) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}
