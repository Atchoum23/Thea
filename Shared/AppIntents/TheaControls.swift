//
//  TheaControls.swift
//  Thea
//
//  Control Center and Lock Screen Controls
//  Available in iOS 18+, macOS 15+
//

import SwiftUI
import AppIntents
import WidgetKit

// MARK: - Quick Ask Control

@available(iOS 18.0, macOS 15.0, *)
struct QuickAskControl: ControlWidget {
    static let kind = "app.thea.control.quickask"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: AskTheaIntent.self
        ) { configuration in
            ControlWidgetButton(action: AskTheaIntent(question: "What can you help me with?")) {
                Label("Ask Thea", systemImage: "bubble.left.fill")
            }
        }
        .displayName("Ask Thea")
        .description("Quick access to ask Thea a question")
    }
}

// MARK: - Focus Session Control

@available(iOS 18.0, macOS 15.0, *)
struct FocusSessionControl: ControlWidget {
    static let kind = "app.thea.control.focus"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: StartFocusSessionIntent.self
        ) { configuration in
            ControlWidgetButton(action: StartFocusSessionIntent()) {
                Label("Focus", systemImage: "timer")
            }
        }
        .displayName("Focus Session")
        .description("Start a focus session")
    }
}

// MARK: - Daily Summary Control

@available(iOS 18.0, macOS 15.0, *)
struct DailySummaryControl: ControlWidget {
    static let kind = "app.thea.control.summary"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: GetDailySummaryIntent.self
        ) { configuration in
            ControlWidgetButton(action: GetDailySummaryIntent()) {
                Label("Summary", systemImage: "chart.bar.fill")
            }
        }
        .displayName("Daily Summary")
        .description("View your daily summary")
    }
}

// MARK: - AI Toggle Control

@available(iOS 18.0, macOS 15.0, *)
struct AIToggleControl: ControlWidget {
    static let kind = "app.thea.control.ai"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            ControlWidgetToggle(
                "On-Device AI",
                isOn: OnDeviceAIToggleIntent.isEnabled,
                action: OnDeviceAIToggleIntent()
            ) { isOn in
                Label(
                    isOn ? "AI On" : "AI Off",
                    systemImage: isOn ? "brain.fill" : "brain"
                )
            }
        }
        .displayName("On-Device AI")
        .description("Toggle on-device AI processing")
    }
}

// MARK: - Smart Home Control

@available(iOS 18.0, macOS 15.0, *)
struct SmartHomeControl: ControlWidget {
    static let kind = "app.thea.control.home"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ControlHomeDeviceIntent.self
        ) { configuration in
            ControlWidgetButton(action: ControlHomeDeviceIntent()) {
                Label("Home", systemImage: "house.fill")
            }
        }
        .displayName("Smart Home")
        .description("Control smart home devices")
    }
}

// MARK: - Toggle Intent

@available(iOS 18.0, macOS 15.0, *)
struct OnDeviceAIToggleIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle On-Device AI"

    @Parameter(title: "Enabled")
    var value: Bool

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "onDeviceAIEnabled")
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(value, forKey: "onDeviceAIEnabled")
        return .result()
    }
}

// MARK: - Control Widget Bundle

@available(iOS 18.0, macOS 15.0, *)
struct TheaControlWidgetBundle: ControlWidgetBundle {
    var body: some ControlWidget {
        QuickAskControl()
        FocusSessionControl()
        DailySummaryControl()
        AIToggleControl()
        SmartHomeControl()
    }
}
