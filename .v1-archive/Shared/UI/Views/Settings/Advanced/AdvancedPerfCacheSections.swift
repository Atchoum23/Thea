//
//  AdvancedPerfCacheSections.swift
//  Thea
//
//  Performance and Cache UI sections for AdvancedSettingsView
//  Extracted from AdvancedSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Performance Section

extension AdvancedSettingsView {
    var performanceSection: some View {
        Group {
            // Memory limit
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Memory Limit")
                    Spacer()
                    Text("\(Int(advancedConfig.memoryLimit)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.memoryLimit, in: 256 ... 2048, step: 128)

                Text("Maximum memory usage before automatic cleanup")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Background tasks
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Max Background Tasks")
                    Spacer()
                    Stepper("\(advancedConfig.maxBackgroundTasks)", value: $advancedConfig.maxBackgroundTasks, in: 1 ... 10)
                }

                Text("Number of concurrent background operations allowed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            Toggle("Preload Models", isOn: $advancedConfig.preloadModels)

            Text("Keep frequently used models in memory for faster responses")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("GPU Acceleration", isOn: $advancedConfig.gpuAcceleration)

            Text("Use GPU for local model inference when available")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Reduce Motion", isOn: $advancedConfig.reduceMotion)

            Toggle("Low Power Mode", isOn: $advancedConfig.lowPowerMode)

            Text("Reduces performance to extend battery life")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Cache Section

extension AdvancedSettingsView {
    var cacheSection: some View {
        Group {
            HStack {
                Text("Cache Size")
                Spacer()
                Text(cacheSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Max Cache Size")
                    Spacer()
                    Text("\(Int(advancedConfig.maxCacheSize)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.maxCacheSize, in: 50 ... 1000, step: 50)
            }

            Divider()

            Toggle("Cache API Responses", isOn: $advancedConfig.cacheAPIResponses)

            Toggle("Cache Model Outputs", isOn: $advancedConfig.cacheModelOutputs)

            Toggle("Cache Images", isOn: $advancedConfig.cacheImages)

            Divider()

            // Cache breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Cache Breakdown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                cacheBreakdownRow(title: "API Responses", size: advancedConfig.apiCacheSize)
                cacheBreakdownRow(title: "Model Outputs", size: advancedConfig.modelCacheSize)
                cacheBreakdownRow(title: "Images", size: advancedConfig.imageCacheSize)
                cacheBreakdownRow(title: "Temporary Files", size: advancedConfig.tempCacheSize)
            }

            Button {
                clearCache()
            } label: {
                Label("Clear All Cache", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    func cacheBreakdownRow(title: String, size: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)

            Spacer()

            Text(size)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
