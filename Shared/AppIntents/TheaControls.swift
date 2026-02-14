//
//  TheaControls.swift
//  Thea
//
//  Control Center and Lock Screen Controls
//  Available in iOS 18+ only (macOS Control Widgets require macOS 26.0+)
//

#if os(iOS)
    import AppIntents
    import SwiftUI
    import WidgetKit

    // MARK: - Control Intent Wrappers

    /// Control-compatible wrapper for AskThea
    @available(iOS 18.0, *)
    struct QuickAskControlIntent: ControlConfigurationIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "Quick Ask Thea"
        nonisolated(unsafe) static var description = IntentDescription("Quickly ask Thea a question")

        func perform() async throws -> some IntentResult {
            // Post notification to open quick ask UI
            await MainActor.run {
                NotificationCenter.default.post(name: .controlCenterQuickAsk, object: nil)
            }
            return .result()
        }
    }

    /// Control-compatible wrapper for Focus Session
    @available(iOS 18.0, *)
    struct FocusSessionControlIntent: ControlConfigurationIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "Start Focus Session"
        nonisolated(unsafe) static var description = IntentDescription("Start a focus session with Thea")

        func perform() async throws -> some IntentResult {
            // Start focus session
            .result()
        }
    }

    /// Control-compatible wrapper for Daily Summary
    @available(iOS 18.0, *)
    struct DailySummaryControlIntent: ControlConfigurationIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "Get Daily Summary"
        nonisolated(unsafe) static var description = IntentDescription("Get your daily summary from Thea")

        func perform() async throws -> some IntentResult {
            // Get daily summary
            .result()
        }
    }

    /// Control-compatible wrapper for Home Device
    @available(iOS 18.0, *)
    struct HomeDeviceControlIntent: ControlConfigurationIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "Control Home Device"
        nonisolated(unsafe) static var description = IntentDescription("Control a smart home device")

        func perform() async throws -> some IntentResult {
            // Control home device
            .result()
        }
    }

    // MARK: - Quick Ask Control

    @available(iOS 18.0, *)
    struct QuickAskControl: ControlWidget {
        static let kind = "app.thea.control.quickask"

        var body: some ControlWidgetConfiguration {
            AppIntentControlConfiguration(
                kind: Self.kind,
                intent: QuickAskControlIntent.self
            ) { _ in
                ControlWidgetButton(action: QuickAskControlIntent()) {
                    Label("Ask Thea", systemImage: "bubble.left.fill")
                }
            }
            .displayName("Ask Thea")
            .description("Quick access to ask Thea a question")
        }
    }

    // MARK: - Focus Session Control

    @available(iOS 18.0, *)
    struct FocusSessionControl: ControlWidget {
        static let kind = "app.thea.control.focus"

        var body: some ControlWidgetConfiguration {
            AppIntentControlConfiguration(
                kind: Self.kind,
                intent: FocusSessionControlIntent.self
            ) { _ in
                ControlWidgetButton(action: FocusSessionControlIntent()) {
                    Label("Focus", systemImage: "timer")
                }
            }
            .displayName("Focus Session")
            .description("Start a focus session")
        }
    }

    // MARK: - Daily Summary Control

    @available(iOS 18.0, *)
    struct DailySummaryControl: ControlWidget {
        static let kind = "app.thea.control.summary"

        var body: some ControlWidgetConfiguration {
            AppIntentControlConfiguration(
                kind: Self.kind,
                intent: DailySummaryControlIntent.self
            ) { _ in
                ControlWidgetButton(action: DailySummaryControlIntent()) {
                    Label("Summary", systemImage: "chart.bar.fill")
                }
            }
            .displayName("Daily Summary")
            .description("View your daily summary")
        }
    }

    // MARK: - AI Toggle Control

    @available(iOS 18.0, *)
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

    @available(iOS 18.0, *)
    struct SmartHomeControl: ControlWidget {
        static let kind = "app.thea.control.home"

        var body: some ControlWidgetConfiguration {
            AppIntentControlConfiguration(
                kind: Self.kind,
                intent: HomeDeviceControlIntent.self
            ) { _ in
                ControlWidgetButton(action: HomeDeviceControlIntent()) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            .displayName("Smart Home")
            .description("Control smart home devices")
        }
    }

    // MARK: - Toggle Intent

    @available(iOS 18.0, *)
    struct OnDeviceAIToggleIntent: SetValueIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "Toggle On-Device AI"

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

    // Note: ControlWidgetBundle requires iOS 18.0+ and is registered separately from WidgetBundle.
    // The individual ControlWidgets (QuickAskControl, FocusSessionControl, etc.) are still available
    // and can be registered via a separate ControlWidgetBundle in the app's main entry point.

#endif
