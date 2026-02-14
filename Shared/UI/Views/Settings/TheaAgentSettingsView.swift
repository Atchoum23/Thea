//
//  TheaAgentSettingsView.swift
//  Thea
//
//  Settings view for sub-agent delegation configuration.
//

import SwiftUI

struct TheaAgentSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable agent delegation", isOn: $settings.agentDelegationEnabled)
                    .accessibilityLabel("Enable agent delegation")
                    .accessibilityHint("Allows Thea to delegate tasks to specialized sub-agents")

                Toggle(
                    "Auto-delegate complex tasks",
                    isOn: $settings.agentAutoDelegateComplexTasks
                )
                .disabled(!settings.agentDelegationEnabled)
                .accessibilityLabel("Automatically delegate complex tasks")
                .accessibilityHint("Thea will automatically delegate multi-step tasks without asking")
            } header: {
                Text("Delegation")
            } footer: {
                Text("When enabled, use @agent prefix in chat to delegate tasks. Auto-delegation lets Thea decide when to use agents.")
            }

            Section("Concurrency") {
                HStack {
                    Text("Max concurrent agents")
                    Spacer()
                    Picker("", selection: $settings.agentMaxConcurrent) {
                        ForEach([1, 2, 3, 4, 6, 8], id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
                .disabled(!settings.agentDelegationEnabled)
            }

            Section("Default Autonomy") {
                Picker("Autonomy level", selection: $settings.agentDefaultAutonomy) {
                    Text("Disabled").tag("disabled")
                    Text("Ask Always").tag("askAlways")
                    Text("Balanced").tag("balanced")
                    Text("Proactive").tag("proactive")
                    Text("Full Auto").tag("fullAuto")
                }
                .disabled(!settings.agentDelegationEnabled)
                .accessibilityLabel("Default autonomy level for agents")
            } footer: {
                Text("Controls how much freedom agents have to take actions. 'Balanced' asks for approval on risky operations.")
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(minWidth: 400)
        #endif
    }
}
