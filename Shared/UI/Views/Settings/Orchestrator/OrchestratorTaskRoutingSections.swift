//
//  OrchestratorTaskRoutingSections.swift
//  Thea
//
//  Task routing UI components for Orchestrator Settings
//  Extracted from OrchestratorSettingsView.swift for better code organization
//

import SwiftUI

#if os(macOS)

// MARK: - Task Routing Section

extension OrchestratorSettingsView {
    var taskRoutingSection: some View {
        Group {
            Toggle("AI-Powered Classification", isOn: $config.useAIForClassification)
                .onChange(of: config.useAIForClassification) { _, _ in
                    saveConfig()
                }

            if config.useAIForClassification {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confidence Threshold: \(Int(config.classificationConfidenceThreshold * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: Binding(
                        get: { Double(config.classificationConfidenceThreshold) },
                        set: { config.classificationConfidenceThreshold = Float($0) }
                    ), in: 0.5 ... 1.0, step: 0.05)
                        .onChange(of: config.classificationConfidenceThreshold) { _, _ in
                            saveConfig()
                        }

                    Text("Higher = more accurate but slower")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text("Fast keyword-based classification")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Routing rules with edit capability
            HStack {
                Text("Routing Rules")
                    .font(.subheadline)

                Spacer()

                Text("\(config.taskRoutingRules.count) configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingRoutingRuleEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            // Routing rules summary
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(config.taskRoutingRules.keys.sorted()), id: \.self) { taskKey in
                        if let models = config.taskRoutingRules[taskKey] {
                            routingRuleRow(taskType: taskKey, models: models)
                        }
                    }
                }
            } label: {
                Text("View All Rules")
                    .font(.caption)
            }
        }
    }

    func routingRuleRow(taskType: String, models: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formatTaskType(taskType))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(models.prefix(2), id: \.self) { model in
                    Text(shortModelName(model))
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(model.hasPrefix("local-") ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundStyle(model.hasPrefix("local-") ? .green : .blue)
                        .cornerRadius(4)
                }
                if models.count > 2 {
                    Text("+\(models.count - 2)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    func shortModelName(_ model: String) -> String {
        if model.hasPrefix("local-") {
            return "🖥️ " + model.replacingOccurrences(of: "local-", with: "")
        }
        let parts = model.split(separator: "/")
        return String(parts.last ?? Substring(model))
    }

    func formatTaskType(_ taskType: String) -> String {
        // Convert camelCase to Title Case with spaces
        var result = ""
        for char in taskType {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}

#endif
