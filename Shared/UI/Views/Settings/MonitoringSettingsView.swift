// MonitoringSettingsView.swift
// Settings for screen and audio monitoring features

import SwiftUI

// periphery:ignore - Reserved: MonitoringSettingsView type reserved for future feature activation
struct MonitoringSettingsView: View {
    @State private var screenCaptureEnabled = false
    @State private var audioCaptureEnabled = false
    @State private var captureFramerate: Double = 5
    @State private var includeMousePosition = true
    @State private var includeClicks = true
    @State private var liveTranscriptionEnabled = false
    @State private var audioSource = AudioSourceOption.systemAudio

    enum AudioSourceOption: String, CaseIterable {
        case systemAudio = "System Audio"
        case microphone = "Microphone"
        case both = "Both"
    }

    var body: some View {
        Form {
            Section("Screen Monitoring") {
                Text("Monitor screen content for AI analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Screen Capture") {
                Toggle("Enable Screen Capture", isOn: $screenCaptureEnabled)

                if screenCaptureEnabled {
                    VStack(alignment: .leading) {
                        Text("Capture Rate: \(Int(captureFramerate)) fps")
                        Slider(value: $captureFramerate, in: 1...30, step: 1)
                    }

                    Toggle("Track Mouse Position", isOn: $includeMousePosition)
                    Toggle("Track Clicks", isOn: $includeClicks)

                    NavigationLink("Select Capture Region") {
                        ScreenRegionSelectorView()
                    }
                }
            }

            #if os(macOS)
            Section("Permissions") {
                HStack {
                    Image(systemName: screenCapturePermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(screenCapturePermissionGranted ? .green : .orange)
                        .accessibilityHidden(true)
                    Text(screenCapturePermissionGranted ? "Screen Recording Enabled" : "Screen Recording Required")
                }
                .accessibilityElement(children: .combine)

                if !screenCapturePermissionGranted {
                    Button("Open System Settings") {
                        openScreenCaptureSettings()
                    }
                }
            }
            #endif

            Section("Audio Monitoring") {
                Text("Monitor audio for transcription and analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Audio Capture") {
                Toggle("Enable Audio Capture", isOn: $audioCaptureEnabled)

                if audioCaptureEnabled {
                    Picker("Audio Source", selection: $audioSource) {
                        ForEach(AudioSourceOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    Toggle("Live Transcription", isOn: $liveTranscriptionEnabled)
                        .help("Transcribe audio in real-time using WhisperKit")
                }
            }

            #if os(macOS)
            Section("Audio Permissions") {
                HStack {
                    Image(systemName: microphonePermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(microphonePermissionGranted ? .green : .orange)
                        .accessibilityHidden(true)
                    Text(microphonePermissionGranted ? "Microphone Access Enabled" : "Microphone Access Required")
                }
                .accessibilityElement(children: .combine)

                if !microphonePermissionGranted {
                    Button("Open System Settings") {
                        openMicrophoneSettings()
                    }
                }
            }
            #endif

            Section("Privacy") {
                Text("Screen and audio monitoring data is processed locally and never sent to external servers unless explicitly requested.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Monitoring")
    }

    #if os(macOS)
    private var screenCapturePermissionGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    private var microphonePermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    #endif
}

// MARK: - Screen Region Selector

struct ScreenRegionSelectorView: View {
    @State private var regionMode = RegionMode.fullScreen

    enum RegionMode: String, CaseIterable {
        case fullScreen = "Full Screen"
        case specificApp = "Specific App"
        case customRegion = "Custom Region"
    }

    var body: some View {
        Form {
            Section {
                Picker("Capture Mode", selection: $regionMode) {
                    ForEach(RegionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch regionMode {
            case .fullScreen:
                Section("Full Screen") {
                    Text("Captures the entire screen content")
                        .foregroundStyle(.secondary)
                }

            case .specificApp:
                Section("Select Application") {
                    Text("Choose an app to monitor")
                        .foregroundStyle(.secondary)
                    // Would show running apps list
                }

            case .customRegion:
                Section("Custom Region") {
                    Text("Draw a region on screen to monitor")
                        .foregroundStyle(.secondary)
                    Button("Select Region") {
                        // Would open region selector
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Capture Region")
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .padding(.bottom)

                Text("Data Collection")
                    .font(.headline)

                Text("""
                THEA is designed with privacy as a core principle:

                • All screen and audio data is processed locally on your device
                • No data is sent to external servers without your explicit consent
                • Captured content is only used for AI analysis during your active session
                • No persistent storage of captured media unless you explicitly save it
                """)

                Text("Permissions")
                    .font(.headline)
                    .padding(.top)

                Text("""
                THEA requires the following permissions for monitoring features:

                • Screen Recording: To capture screen content for visual analysis
                • Microphone: To capture audio for transcription
                • Accessibility: For enhanced interaction capabilities

                You can revoke these permissions at any time in System Settings.
                """)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

#if os(macOS)
import AVFoundation
import AppKit
#endif
