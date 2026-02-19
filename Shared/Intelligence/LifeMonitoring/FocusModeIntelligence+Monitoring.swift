// FocusModeIntelligence+Monitoring.swift
// THEA - macOS & iOS Focus Mode Detection and System File Parsing
// Split from FocusModeIntelligence.swift

import Foundation
import Intents
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Focus Mode Detection & Monitoring

extension FocusModeIntelligence {

    // MARK: - macOS Focus Mode Detection

    #if os(macOS)

    /// Start monitoring macOS Focus mode by watching the DoNotDisturb database directory.
    ///
    /// Reads `~/Library/DoNotDisturb/DB/` for `Assertions.json` (active focus)
    /// and `ModeConfigurations.json` (all configured focus modes).
    /// Sets up a file system event source to detect changes in real time.
    func startMacOSFocusMonitoring() async {
        let doNotDisturbPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB"

        // Initial read
        await readCurrentFocusModeFromMacOS()

        // Monitor for changes
        let fileDescriptor = open(doNotDisturbPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[FocusMode] Failed to open DoNotDisturb directory for monitoring")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.readCurrentFocusModeFromMacOS()
            }
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        setFocusDBMonitor(source)
    }

    /// Read current Focus mode state from macOS system files.
    ///
    /// Parses `Assertions.json` for the currently active focus mode
    /// and `ModeConfigurations.json` for all available mode definitions.
    func readCurrentFocusModeFromMacOS() async {
        let assertionsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"
        let configurationsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/ModeConfigurations.json"

        do {
            // Read current active Focus
            if let assertionsData = FileManager.default.contents(atPath: assertionsPath) {
                let assertions = try JSONDecoder().decode(FocusAssertions.self, from: assertionsData)
                await processFocusAssertions(assertions)
            }

            // Read all Focus configurations
            if let configData = FileManager.default.contents(atPath: configurationsPath) {
                let configs = try JSONDecoder().decode(FocusModeConfigurations.self, from: configData)
                await processFocusModeConfigurations(configs)
            }
        } catch {
            print("[FocusMode] Error reading Focus data: \(error)")
        }
    }

    // MARK: - macOS Focus JSON Structures

    /// Represents the contents of `~/Library/DoNotDisturb/DB/Assertions.json`.
    struct FocusAssertions: Codable {
        let data: [AssertionData]?

        struct AssertionData: Codable {
            let storeAssertionRecords: [AssertionRecord]?
        }

        struct AssertionRecord: Codable {
            let assertionDetails: AssertionDetails?
        }

        struct AssertionDetails: Codable {
            let assertionDetailsModeIdentifier: String?
        }
    }

    /// Represents the contents of `~/Library/DoNotDisturb/DB/ModeConfigurations.json`.
    struct FocusModeConfigurations: Codable {
        let data: [ModeData]?

        struct ModeData: Codable {
            let modeConfigurations: [String: ModeConfig]?
        }

        struct ModeConfig: Codable {
            let name: String?
            let identifier: String?
            let semanticType: Int?
            let configuration: Configuration?

            struct Configuration: Codable {
                let allowRepeatedCalls: Bool?
                let allowedContactsRule: String?
                let allowedApplicationsRule: String?
            }
        }
    }

    // MARK: - Focus Assertion Processing

    /// Process parsed focus assertions to determine which mode is currently active.
    ///
    /// Compares the active mode identifier against known modes and triggers
    /// activation/deactivation handlers as needed.
    ///
    /// - Parameter assertions: The decoded `FocusAssertions` from the system file.
    func processFocusAssertions(_ assertions: FocusAssertions) async {
        var activeModeId: String?

        if let data = assertions.data?.first,
           let records = data.storeAssertionRecords {
            for record in records {
                if let modeId = record.assertionDetails?.assertionDetailsModeIdentifier {
                    activeModeId = modeId
                    break
                }
            }
        }

        if let modeId = activeModeId {
            // Focus mode is active
            if getCurrentFocusMode()?.id != modeId {
                if let mode = getFocusMode(modeId) {
                    var activeMode = mode
                    activeMode.isActive = true
                    setCurrentFocusModeValue(activeMode)
                    await handleFocusModeActivated(activeMode)
                    notifyFocusModeChanged(activeMode)
                }
            }
        } else {
            // No Focus mode active
            if let previousMode = getCurrentFocusMode() {
                setCurrentFocusModeValue(nil)
                await handleFocusModeDeactivated(previousMode)
                notifyFocusModeChanged(nil)
            }
        }
    }

    /// Process parsed focus mode configurations to register all available modes.
    ///
    /// Only adds modes that don't already have THEA-specific settings configured.
    ///
    /// - Parameter configs: The decoded `FocusModeConfigurations` from the system file.
    func processFocusModeConfigurations(_ configs: FocusModeConfigurations) async {
        guard let data = configs.data?.first,
              let modeConfigs = data.modeConfigurations else { return }

        for (modeId, config) in modeConfigs {
            if getFocusMode(modeId) == nil {
                let mode = FocusModeConfiguration(
                    id: modeId,
                    name: config.name ?? "Unknown",
                    allowRepeatedCalls: config.configuration?.allowRepeatedCalls ?? true
                )
                setFocusMode(modeId, mode: mode)
            }
        }
    }

    #endif

    // MARK: - iOS Focus Mode Detection

    /// Start monitoring Focus mode on iOS via `INFocusStatusCenter`.
    ///
    /// Note: iOS does not expose which specific Focus mode is active,
    /// only whether any Focus mode is enabled. Shortcuts automations
    /// are used to bridge this gap.
    // periphery:ignore - Reserved: startIOSFocusMonitoring() instance method reserved for future feature activation
    func startIOSFocusMonitoring() async {
        let center = INFocusStatusCenter.default

        let status = await center.requestAuthorization()
        print("[FocusMode] iOS authorization status: \(status)")
    }
}
