import SwiftUI

struct LifeTrackingSettingsView: View {
    @State private var config = AppConfiguration.shared.lifeTrackingConfig
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                Text("Thea can track various aspects of your life to provide personalized insights and coaching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Life Tracking", systemImage: "chart.xyaxis.line")
            }

            #if os(iOS) || os(watchOS)
                Section("Health & Fitness") {
                    Toggle("Health Tracking (HealthKit)", isOn: $config.healthTrackingEnabled)
                        .onChange(of: config.healthTrackingEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    try? await HealthTrackingManager.shared.requestAuthorization()
                                }
                            }
                        }
                }
            #endif

            #if os(macOS)
                Section("Digital Activity") {
                    Toggle("Screen Time Tracking", isOn: $config.screenTimeTrackingEnabled)
                    Toggle("Input Activity (Mouse/Keyboard)", isOn: $config.inputTrackingEnabled)
                    Toggle("Browsing History", isOn: $config.browserTrackingEnabled)
                }
            #endif

            #if os(iOS)
                Section("Location") {
                    Toggle("Location Tracking", isOn: $config.locationTrackingEnabled)
                        .onChange(of: config.locationTrackingEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    _ = await LocationTrackingManager.shared.requestPermission()
                                }
                            }
                        }
                }
            #endif

            Section("Data Retention") {
                Picker("Keep tracking data for", selection: $config.dataRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                    Text("Forever").tag(Int.max)
                }
            }

            Section("Privacy") {
                Toggle("Encrypt tracking data", isOn: $config.encryptTrackingData)
                Toggle("Auto-delete old data", isOn: $config.autoDeleteOldData)
            }

            Section("Notifications") {
                Toggle("Daily insights", isOn: $config.dailyInsightsEnabled)
                Toggle("Weekly reports", isOn: $config.weeklyReportEnabled)
                Toggle("Achievement notifications", isOn: $config.achievementNotificationsEnabled)
            }

            Section("Data Management") {
                Button("Delete All Tracking Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Life Tracking")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.lifeTrackingConfig = newValue
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete all tracking data
            }
        } message: {
            Text("This will permanently delete all tracked life data. This action cannot be undone.")
        }
    }
}
