//
//  AdvancedDevNetworkSections.swift
//  Thea
//
//  Development and Network UI sections for AdvancedSettingsView
//  Extracted from AdvancedSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Development Section

extension AdvancedSettingsView {
    var developmentSection: some View {
        Group {
            Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)

            Text("Shows additional debugging information in the UI")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)

            Text("Display real-time performance data in conversations")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Show Token Counts", isOn: $advancedConfig.showTokenCounts)

            Toggle("Show Model Latency", isOn: $advancedConfig.showModelLatency)

            Toggle("Show Memory Usage", isOn: $advancedConfig.showMemoryUsage)
        }
    }
}

// MARK: - Network Section

extension AdvancedSettingsView {
    var networkSection: some View {
        Group {
            Toggle("Use Proxy", isOn: $advancedConfig.useProxy)

            if advancedConfig.useProxy {
                TextField("Proxy Host", text: $advancedConfig.proxyHost)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Proxy Port")
                    Spacer()
                    TextField("Port", value: $advancedConfig.proxyPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                Picker("Proxy Type", selection: $advancedConfig.proxyType) {
                    Text("HTTP").tag(AdvancedProxyType.http)
                    Text("HTTPS").tag(AdvancedProxyType.https)
                    Text("SOCKS5").tag(AdvancedProxyType.socks5)
                }
            }

            Divider()

            // Timeout settings
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Request Timeout")
                    Spacer()
                    Text("\(Int(advancedConfig.requestTimeout)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.requestTimeout, in: 10 ... 300, step: 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Connection Timeout")
                    Spacer()
                    Text("\(Int(advancedConfig.connectionTimeout)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.connectionTimeout, in: 5 ... 60, step: 5)
            }

            Divider()

            // Custom headers
            Toggle("Custom HTTP Headers", isOn: $advancedConfig.useCustomHeaders)

            if advancedConfig.useCustomHeaders {
                ForEach(advancedConfig.customHeaders.indices, id: \.self) { index in
                    HStack {
                        TextField("Header", text: $advancedConfig.customHeaders[index].key)
                            .textFieldStyle(.roundedBorder)

                        TextField("Value", text: $advancedConfig.customHeaders[index].value)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            advancedConfig.customHeaders.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    advancedConfig.customHeaders.append(AdvancedHTTPHeader(key: "", value: ""))
                } label: {
                    Label("Add Header", systemImage: "plus")
                }
            }
        }
    }
}
