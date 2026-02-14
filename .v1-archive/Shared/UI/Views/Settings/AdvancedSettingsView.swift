// AdvancedSettingsView.swift
// Comprehensive advanced settings for Thea
//
// Split into extensions:
// - AdvancedSettingsTypes.swift: Configuration and supporting types
// - AdvancedOverviewSection.swift: System overview UI
// - AdvancedDevNetworkSections.swift: Development and Network sections
// - AdvancedLoggingSection.swift: Logging section
// - AdvancedPerfCacheSections.swift: Performance and Cache sections
// - AdvancedExpDiagSections.swift: Experimental and Diagnostics sections
// - AdvancedSheetsActions.swift: Sheet views and action methods

import SwiftUI

struct AdvancedSettingsView: View {
    @State var settingsManager = SettingsManager.shared
    @State var advancedConfig = AdvancedSettingsConfiguration.load()
    @State var showingDiagnosticReport = false
    @State var showingLogViewer = false
    @State var isGeneratingReport = false
    @State var cacheSize = "Calculating..."
    @State var memoryUsage = "Calculating..."

    var body: some View {
        Form {
            // MARK: - Overview
            Section("System Overview") {
                systemOverview
            }

            // MARK: - Development
            Section("Development") {
                developmentSection
            }

            // MARK: - Network
            Section("Network") {
                networkSection
            }

            // MARK: - Logging
            Section("Logging") {
                loggingSection
            }

            // MARK: - Performance
            Section("Performance") {
                performanceSection
            }

            // MARK: - Cache
            Section("Cache & Storage") {
                cacheSection
            }

            // MARK: - Experimental
            Section("Experimental Features") {
                experimentalSection
            }

            // MARK: - Diagnostics
            Section("Diagnostics") {
                diagnosticsSection
            }

            // MARK: - Reset
            Section {
                Button("Reset Advanced Settings", role: .destructive) {
                    resetAdvancedSettings()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onAppear {
            calculateCacheSize()
            calculateMemoryUsage()
        }
        .onChange(of: advancedConfig) { _, _ in
            advancedConfig.save()
        }
        .sheet(isPresented: $showingDiagnosticReport) {
            diagnosticReportSheet
        }
        .sheet(isPresented: $showingLogViewer) {
            logViewerSheet
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    AdvancedSettingsView()
        .frame(width: 700, height: 900)
}
#else
#Preview {
    NavigationStack {
        AdvancedSettingsView()
            .navigationTitle("Advanced")
    }
}
#endif
