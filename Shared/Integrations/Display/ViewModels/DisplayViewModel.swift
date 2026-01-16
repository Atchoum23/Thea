import Foundation
import SwiftUI

#if os(macOS)
import CoreGraphics

/// View model for display management
@MainActor
@Observable
public final class DisplayViewModel {

    // MARK: - Published State

    public var displays: [Display] = []
    public var selectedDisplay: Display?
    public var currentProfile: DisplayProfile?
    public var schedules: [DisplaySchedule] = []
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Dependencies

    private let displayService: DisplayService

    // MARK: - Initialization

    public init(displayService: DisplayService = DisplayService()) {
        self.displayService = displayService
    }

    // MARK: - Data Loading

    public func loadDisplays() async {
        isLoading = true
        errorMessage = nil

        do {
            displays = try await displayService.fetchDisplays()

            if let first = displays.first {
                selectedDisplay = first
                await loadCurrentProfile()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func refreshData() async {
        await loadDisplays()
    }

    private func loadCurrentProfile() async {
        guard let displayID = selectedDisplay?.displayID else { return }

        do {
            currentProfile = try await displayService.getCurrentState(for: displayID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Profile Management

    public func applyProfile(_ profile: DisplayProfile) async {
        guard let displayID = selectedDisplay?.displayID else { return }

        do {
            try await displayService.applyProfile(profile, to: displayID)
            currentProfile = profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setBrightness(_ value: Int) async {
        guard let displayID = selectedDisplay?.displayID else { return }

        do {
            try await displayService.setBrightness(value, for: displayID)
            currentProfile?.brightness = value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setContrast(_ value: Int) async {
        guard let displayID = selectedDisplay?.displayID else { return }

        do {
            try await displayService.setContrast(value, for: displayID)
            currentProfile?.contrast = value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Scheduling

    public func setSchedule(_ schedule: DisplaySchedule) async {
        guard let displayID = selectedDisplay?.displayID else { return }

        do {
            try await displayService.setSchedule(schedule, for: displayID)
            if !schedules.contains(where: { $0.id == schedule.id }) {
                schedules.append(schedule)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    public var hasMultipleDisplays: Bool {
        displays.count > 1
    }

    public var supportsHardwareControl: Bool {
        selectedDisplay?.supportsHardwareControl ?? false
    }

    public var isBuiltIn: Bool {
        selectedDisplay?.isBuiltIn ?? false
    }

    public var presetProfiles: [DisplayProfile] {
        [.daytime, .evening, .night, .reading, .movie]
    }
}

#endif
