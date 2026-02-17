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
        private static let profilesKey = "thea.display.profiles"

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

        /// Adds a new display profile and persists it to UserDefaults.
        public func createProfile(_ profile: DisplayProfile) async {
            profiles.append(profile)
            await saveProfiles()
        }

        /// Updates an existing display profile by ID.
        public func updateProfile(_ profile: DisplayProfile) async throws {
            guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
                throw ProfileError.profileNotFound
            }
            profiles[index] = profile
            await saveProfiles()
        }

        /// Deletes the display profile with the given ID.
        public func deleteProfile(id: UUID) async throws {
            guard profiles.contains(where: { $0.id == id }) else {
                throw ProfileError.profileNotFound
            }
            profiles.removeAll { $0.id == id }
            await saveProfiles()
        }

        /// Returns all saved display profiles.
        public func getProfiles() async -> [DisplayProfile] {
            profiles
        }

        /// Returns the display profile with the given ID, or throws if not found.
        public func getProfile(id: UUID) async throws -> DisplayProfile {
            guard let profile = profiles.first(where: { $0.id == id }) else {
                throw ProfileError.profileNotFound
            }
            return profile
        }

        // MARK: - Profile Application

        /// Applies a display profile's brightness and contrast settings to the given display.
        public func applyProfile(_ profile: DisplayProfile, to displayID: CGDirectDisplayID) async throws {
            let displayService = DisplayService()

            do {
                try await displayService.setBrightness(profile.brightness, for: displayID)
                try await displayService.setContrast(profile.contrast, for: displayID)
            } catch {
                throw ProfileError.applyFailed
            }

            activeProfile = profile
        }

        /// Applies a display profile to all currently active displays.
        public func applyProfileToAllDisplays(_ profile: DisplayProfile) async throws {
            let displays = getActiveDisplays()

            for displayID in displays {
                try await applyProfile(profile, to: displayID)
            }
        }

        /// Returns the currently active display profile, if any.
        public func getActiveProfile() async -> DisplayProfile? {
            activeProfile
        }

        // MARK: - Automatic Switching

        /// Enables circadian-based automatic profile switching (checks every 15 minutes).
        public func enableAutomaticSwitching() async {
            automaticSwitching = true
            await startCircadianMonitoring()
        }

        /// Disables automatic circadian profile switching.
        public func disableAutomaticSwitching() async {
            automaticSwitching = false
        }

        /// Returns whether automatic circadian profile switching is enabled.
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
            if let data = UserDefaults.standard.data(forKey: Self.profilesKey),
               let saved = try? JSONDecoder().decode([DisplayProfile].self, from: data)
            {
                profiles = saved
            } else {
                profiles = [.daytime, .evening, .night, .reading, .movie]
            }
        }

        private func saveProfiles() async {
            if let data = try? JSONEncoder().encode(profiles) {
                UserDefaults.standard.set(data, forKey: Self.profilesKey)
            }
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
