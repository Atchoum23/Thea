//
//  ConditionPickerSheet.swift
//  Thea
//
//  Condition picker sheet for selecting task trigger conditions
//  Extracted from AutonomousTaskSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Condition Picker Sheet

struct ConditionPickerSheet: View {
    let onSelect: (TaskCondition) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ConditionType = .focusMode
    @State private var scheduleHour = 9
    @State private var scheduleMinute = 0
    @State private var awayMinutes = 5
    @State private var batteryThreshold = 20
    @State private var appBundleId = ""
    @State private var networkType: NetworkType = .any

    enum ConditionType: String, CaseIterable {
        case focusMode = "Focus Mode Active"
        case userAway = "User Away"
        case deviceLocked = "Device Locked"
        case dailySchedule = "Daily Schedule"
        case batteryLevel = "Battery Level"
        case appRunning = "App Running"
        case networkConnected = "Network Connected"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Condition Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ConditionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Configuration") {
                    conditionConfiguration
                }
            }
            .navigationTitle("Add Condition")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCondition()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 400)
        #endif
    }

    @ViewBuilder
    private var conditionConfiguration: some View {
        switch selectedType {
        case .focusMode:
            Text("Triggers when any Focus mode is active")
                .foregroundStyle(.secondary)

        case .userAway:
            Stepper("Minutes away: \(awayMinutes)", value: $awayMinutes, in: 1...60)

        case .deviceLocked:
            Text("Triggers when device screen is locked")
                .foregroundStyle(.secondary)

        case .dailySchedule:
            HStack {
                Picker("Hour", selection: $scheduleHour) {
                    ForEach(0..<24, id: \.self) { Text("\($0)").tag($0) }
                }
                .frame(width: 80)
                Text(":")
                Picker("Minute", selection: $scheduleMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .frame(width: 80)
            }

        case .batteryLevel:
            Stepper("Below \(batteryThreshold)%", value: $batteryThreshold, in: 5...50, step: 5)

        case .appRunning:
            TextField("Bundle ID (e.g., com.apple.mail)", text: $appBundleId)

        case .networkConnected:
            Picker("Network Type", selection: $networkType) {
                Text("Any").tag(NetworkType.any)
                Text("WiFi").tag(NetworkType.wifi)
                Text("Cellular").tag(NetworkType.cellular)
            }
        }
    }

    private func addCondition() {
        let condition: TaskCondition
        switch selectedType {
        case .focusMode:
            condition = .focusModeActive
        case .userAway:
            condition = .userAway(durationMinutes: awayMinutes)
        case .deviceLocked:
            condition = .deviceLocked
        case .dailySchedule:
            condition = .scheduled(.daily(hour: scheduleHour, minute: scheduleMinute))
        case .batteryLevel:
            condition = .batteryLevel(below: batteryThreshold)
        case .appRunning:
            condition = .appRunning(bundleId: appBundleId.isEmpty ? "com.apple.mail" : appBundleId)
        case .networkConnected:
            condition = .networkConnected(type: networkType)
        }
        onSelect(condition)
        dismiss()
    }
}
