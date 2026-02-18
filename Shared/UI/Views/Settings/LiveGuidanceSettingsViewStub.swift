// LiveGuidanceSettingsViewStub.swift
// Stub for LiveGuidanceSettingsView when LocalVisionGuidance dependencies are excluded
// Replace this file's contents with nothing when MLXAudioEngine is enabled

#if os(macOS)
import SwiftUI

// This stub is compiled when LiveGuidanceSettingsView.swift is excluded from the build
// (i.e., when MLXAudioEngine/MLXVoiceBackend are temporarily excluded)
// When those dependencies are re-enabled, remove this file and un-exclude LiveGuidanceSettingsView.swift
struct LiveGuidanceSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Live Guidance")
                .font(.title2)
            Text("Live screen monitoring requires MLX audio components.\nRe-enable MLXAudioEngine to use this feature.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
#endif
