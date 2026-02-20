// NotificationIntelligenceView.swift
// Thea — Smart Notification Settings
// Shows SmartNotificationScheduler config and delivery stats

import SwiftUI

#if os(macOS)
struct NotificationIntelligenceView: View {
    @State private var scheduler = SmartNotificationScheduler.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Notification Intelligence")
                    .font(.largeTitle.bold())

                GroupBox("Smart Scheduling") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable smart scheduling", isOn: Binding(
                            get: { scheduler.isEnabled },
                            set: { scheduler.isEnabled = $0 }
                        ))
                        HStack {
                            Text("Max delay")
                            Spacer()
                            Stepper("\(scheduler.maxDelayHours)h",
                                    value: Binding(
                                        get: { scheduler.maxDelayHours },
                                        set: { scheduler.maxDelayHours = $0 }
                                    ),
                                    in: 1...12)
                                .fixedSize()
                        }
                        HStack {
                            Text("Receptivity threshold")
                            Spacer()
                            Text(String(format: "%.0f%%", scheduler.receptivityThreshold * 100))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                GroupBox("Delivery Statistics") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Delivered immediately", systemImage: "bell.fill")
                            Spacer()
                            Text("\(scheduler.immediateCount)").foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Deferred for better timing", systemImage: "clock.fill")
                            Spacer()
                            Text("\(scheduler.deferredCount)").foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Total scheduled", systemImage: "tray.fill")
                            Spacer()
                            Text("\(scheduler.scheduledCount)").foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding()
        }
    }
}
#endif
