#if os(macOS)
    import AppKit
    import CoreGraphics
    import Foundation

    /// Manager for display profiles and automated switching
    public actor DisplayProfileManager {
        public static let shared = DisplayProfileManager()

        private var profiles: [DisplayProfile] = []
        private var activeProfile: DisplayProfile?
        private var automaticSwitching = false

        public enum ProfileError: Error, Sendable, LocalizedError {
            case profileNotFound
            case applyFailed
            case displayNotAvailable

            public var errorDescription: String? {
                switch self {
                case .profileNotFound:
                    "Display profile not found"
                case .applyFailed:
                    "Failed to apply display settings"
                case .displayNotAvailable:
                    "Display is not available"
                }
            }
        }

        private init() {
            Task {
                await loadDefaultProfiles()
            }
        }

        // MARK: - Profile Management

        public func createProfile(_ profile: DisplayProfile) async {
            profiles.append(profile)
            await saveProfiles()
        }

        public func updateProfile(_ profile: DisplayProfile) async throws {
            guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
                throw ProfileError.profileNotFound
            }
            profiles[index] = profile
            await saveProfiles()
        }

        public func deleteProfile(id: UUID) async throws {
            guard profiles.contains(where: { $0.id == id }) else {
                throw ProfileError.profileNotFound
            }
            profiles.removeAll { $0.id == id }
            await saveProfiles()
        }

        public func getProfiles() async -> [DisplayProfile] {
            profiles
        }

        public func getProfile(id: UUID) async throws -> DisplayProfile {
            guard let profile = profiles.first(where: { $0.id == id }) else {
                throw ProfileError.profileNotFound
            }
            return profile
        }

        // MARK: - Profile Application

        public func applyProfile(_ profile: DisplayProfile, to _: CGDirectDisplayID) async throws {
            // Note: Actual DDC/CI implementation requires IOKit framework and is complex
            // This is a simplified version that sets software-based brightness

            // Set brightness using CoreGraphics
            // Note: CGDisplaySetUserBrightness is deprecated/unavailable in newer macOS
            // TODO: Implement using DDC/CI or alternative APIs
            // var brightness = Float(profile.brightness) / 100.0
            // CGDisplaySetUserBrightness(displayID, brightness)

            activeProfile = profile
        }

        public func applyProfileToAllDisplays(_ profile: DisplayProfile) async throws {
            let displays = getActiveDisplays()

            for displayID in displays {
                try await applyProfile(profile, to: displayID)
            }
        }

        public func getActiveProfile() async -> DisplayProfile? {
            activeProfile
        }

        // MARK: - Automatic Switching

        public func enableAutomaticSwitching() async {
            automaticSwitching = true
            await startCircadianMonitoring()
        }

        public func disableAutomaticSwitching() async {
            automaticSwitching = false
        }

        public func isAutomaticSwitchingEnabled() async -> Bool {
            automaticSwitching
        }

        // MARK: - Circadian Integration

        private func startCircadianMonitoring() async {
            // Monitor time of day and apply appropriate profile
            Task {
                while automaticSwitching {
                    let hour = Calendar.current.component(.hour, from: Date())
                    let recommendedProfile = await getRecommendedProfile(for: hour)

                    if let profile = recommendedProfile, profile.id != activeProfile?.id {
                        try? await applyProfileToAllDisplays(profile)
                    }

                    // Check every 15 minutes
                    try? await Task.sleep(for: .seconds(900))
                }
            }
        }

        private func getRecommendedProfile(for hour: Int) async -> DisplayProfile? {
            if hour >= 6, hour < 18 {
                .daytime
            } else if hour >= 18, hour < 22 {
                .evening
            } else {
                .night
            }
        }

        // MARK: - Private Helpers

        private func loadDefaultProfiles() async {
            profiles = [
                .daytime,
                .evening,
                .night,
                .reading,
                .movie
            ]
        }

        private func saveProfiles() async {
            // TODO: Persist to disk using SwiftData or UserDefaults
        }

        private func getActiveDisplays() -> [CGDirectDisplayID] {
            var displayCount: UInt32 = 0
            var result = CGGetActiveDisplayList(0, nil, &displayCount)
            guard result == .success else { return [] }

            let allocated = Int(displayCount)
            let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
            defer { activeDisplays.deallocate() }

            result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
            guard result == .success else { return [] }

            return Array(UnsafeBufferPointer(start: activeDisplays, count: Int(displayCount)))
        }
    }

#endif
