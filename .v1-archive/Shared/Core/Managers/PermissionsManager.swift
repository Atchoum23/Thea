import AVFoundation
import Contacts
import CoreLocation
import EventKit
import Foundation
import Photos
import Speech
@preconcurrency import UserNotifications

#if canImport(CoreBluetooth)
    import CoreBluetooth
#endif

#if canImport(CoreMotion)
    import CoreMotion
#endif

#if canImport(HealthKit)
    import HealthKit
#endif

#if canImport(HomeKit)
    import HomeKit
#endif

#if canImport(LocalAuthentication)
    import LocalAuthentication
#endif

#if canImport(MediaPlayer)
    import MediaPlayer
#endif

#if canImport(Intents)
    import Intents
#endif

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// Types moved to PermissionsTypes.swift:
// - PermissionStatus
// - PermissionCategory
// - PermissionType
// - PermissionInfo

// MARK: - Permissions Manager

@MainActor
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    // MARK: - State

    private(set) var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// All permissions with their current status
    private(set) var allPermissions: [PermissionInfo] = []

    /// Loading state
    private(set) var isRefreshing = false

    /// Last refresh date
    private(set) var lastRefreshDate: Date?

    // Legacy permission states (for backward compatibility)
    private(set) var speechRecognitionStatus: PermissionStatus = .notDetermined
    private(set) var microphoneStatus: PermissionStatus = .notDetermined
    private(set) var notificationsStatus: PermissionStatus = .notDetermined
    private(set) var contactsStatus: PermissionStatus = .notDetermined
    private(set) var calendarStatus: PermissionStatus = .notDetermined
    private(set) var photosStatus: PermissionStatus = .notDetermined
    private(set) var locationStatus: PermissionStatus = .notDetermined
    private(set) var fullDiskAccessStatus: PermissionStatus = .notDetermined
    private(set) var cameraStatus: PermissionStatus = .notDetermined
    private(set) var bluetoothStatus: PermissionStatus = .notDetermined
    private(set) var siriStatus: PermissionStatus = .notDetermined
    private(set) var healthStatus: PermissionStatus = .notDetermined
    private(set) var homeKitStatus: PermissionStatus = .notDetermined
    private(set) var accessibilityStatus: PermissionStatus = .notDetermined
    private(set) var screenRecordingStatus: PermissionStatus = .notDetermined

    private init() {
        checkAllPermissions()
        refreshAllPermissionsAsync()
    }

    // MARK: - Refresh All Permissions

    /// Refresh all permissions asynchronously
    func refreshAllPermissionsAsync() {
        Task {
            await refreshAllPermissions()
        }
    }

    /// Refresh all permissions and update the allPermissions array
    func refreshAllPermissions() async {
        isRefreshing = true

        var permissions: [PermissionInfo] = []

        // Get platform-specific permission types
        let types = getPlatformPermissionTypes()

        for type in types {
            let status = await getPermissionStatus(for: type)
            permissions.append(PermissionInfo(type: type, status: status))
        }

        allPermissions = permissions.sorted { $0.category.rawValue < $1.category.rawValue }
        lastRefreshDate = Date()
        isRefreshing = false
    }

    /// Get permissions by category
    func permissions(for category: PermissionCategory) -> [PermissionInfo] {
        allPermissions.filter { $0.category == category }
    }

    /// Get available categories (that have at least one permission)
    var availableCategories: [PermissionCategory] {
        let categories = Set(allPermissions.map(\.category))
        return PermissionCategory.allCases.filter { categories.contains($0) }
    }

    /// Get permission types available on current platform
    private func getPlatformPermissionTypes() -> [PermissionType] {
        #if os(macOS)
            return [
                .camera, .microphone, .photoLibrary, .contacts, .calendars, .reminders,
                .locationWhenInUse, .locationAlways,
                .notifications,
                .mediaLibrary, .speechRecognition,
                .homeKit, .siri,
                .bluetooth, .localNetwork, .faceID,
                .accessibility, .fullDiskAccess, .screenRecording, .inputMonitoring, .automation,
                .focusStatus
            ]
        #elseif os(iOS)
            return [
                .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
                .contacts, .calendars, .reminders,
                .locationWhenInUse, .locationAlways,
                .healthRead, .healthWrite, .motionFitness,
                .notifications, .criticalAlerts,
                .mediaLibrary, .speechRecognition,
                .homeKit, .siri,
                .bluetooth, .localNetwork, .faceID,
                .focusStatus
            ]
        #elseif os(watchOS)
            return [
                .contacts, .calendars, .reminders,
                .locationWhenInUse, .locationAlways,
                .healthRead, .healthWrite, .motionFitness,
                .notifications,
                .bluetooth, .siri
            ]
        #elseif os(tvOS)
            return [
                .locationWhenInUse,
                .notifications,
                .bluetooth, .siri, .homeKit
            ]
        #else
            return []
        #endif
    }

    /// Get status for a specific permission type
    func getPermissionStatus(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .camera:
            return checkCameraStatus()
        case .microphone:
            return checkMicrophoneStatus()
        case .photoLibrary:
            return checkPhotoLibraryStatus()
        case .photoLibraryAddOnly:
            return checkPhotoLibraryAddOnlyStatus()
        case .contacts:
            return checkContactsStatus()
        case .calendars:
            return checkCalendarStatus()
        case .reminders:
            return checkRemindersStatus()
        case .locationWhenInUse, .locationAlways:
            return checkLocationStatus()
        case .healthRead, .healthWrite:
            return checkHealthKitStatus()
        case .motionFitness:
            return checkMotionFitnessStatus()
        case .notifications:
            return await checkNotificationsStatus()
        case .criticalAlerts:
            return await checkCriticalAlertsStatus()
        case .mediaLibrary:
            return checkMediaLibraryStatus()
        case .speechRecognition:
            return checkSpeechRecognitionStatus()
        case .homeKit:
            return .notDetermined // HomeKit doesn't have a status API
        case .siri:
            return checkSiriStatus()
        case .bluetooth:
            return checkBluetoothStatus()
        case .localNetwork:
            return .notDetermined // No API to check
        case .faceID:
            return checkFaceIDStatus()
        case .accessibility:
            return checkAccessibilityStatus()
        case .fullDiskAccess:
            return checkFullDiskAccess()
        case .screenRecording:
            return checkScreenRecordingStatus()
        case .inputMonitoring:
            return checkInputMonitoringStatus()
        case .automation:
            return .notDetermined // Requires manual check
        case .focusStatus:
            return .notDetermined // Requires Focus API
        }
    }

    // MARK: - Individual Status Checks

    private func checkCameraStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private func checkMicrophoneStatus() -> PermissionStatus {
        #if os(macOS)
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .authorized
            case .denied: return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        #endif
    }

    private func checkPhotoLibraryStatus() -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .notDetermined
        }
    }

    private func checkPhotoLibraryAddOnlyStatus() -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .notDetermined
        }
    }

    private func checkContactsStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .notDetermined
        }
    }

    private func checkCalendarStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .authorized
        case .writeOnly: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private func checkRemindersStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .authorized
        case .writeOnly: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private func checkLocationStatus() -> PermissionStatus {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorizedAlways: return .authorized
        case .authorizedWhenInUse: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private func checkHealthKitStatus() -> PermissionStatus {
        #if canImport(HealthKit) && !os(macOS) && !os(tvOS)
            guard HKHealthStore.isHealthDataAvailable() else {
                return .notAvailable
            }
            return .notDetermined // HealthKit requires per-type checks
        #else
            return .notAvailable
        #endif
    }

    private func checkMotionFitnessStatus() -> PermissionStatus {
        #if canImport(CoreMotion) && !os(macOS) && !os(tvOS)
            switch CMMotionActivityManager.authorizationStatus() {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            return .notAvailable
        #endif
    }

    private func checkNotificationsStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        @unknown default: return .notDetermined
        }
    }

    private func checkCriticalAlertsStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.criticalAlertSetting {
        case .enabled: return .authorized
        case .disabled: return .denied
        case .notSupported: return .notAvailable
        @unknown default: return .notDetermined
        }
    }

    private func checkMediaLibraryStatus() -> PermissionStatus {
        #if os(iOS)
            switch MPMediaLibrary.authorizationStatus() {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            return .notAvailable
        #endif
    }

    private func checkSpeechRecognitionStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private func checkSiriStatus() -> PermissionStatus {
        #if os(iOS) || os(watchOS)
            switch INPreferences.siriAuthorizationStatus() {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            return .notAvailable
        #endif
    }

    private func checkBluetoothStatus() -> PermissionStatus {
        #if canImport(CoreBluetooth)
            switch CBManager.authorization {
            case .notDetermined: return .notDetermined
            case .allowedAlways: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            return .notAvailable
        #endif
    }

    private func checkFaceIDStatus() -> PermissionStatus {
        #if canImport(LocalAuthentication)
            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                return .authorized
            }
            if let laError = error as? LAError {
                switch laError.code {
                case .biometryNotEnrolled: return .notDetermined
                case .biometryLockout: return .restricted
                case .biometryNotAvailable: return .notAvailable
                default: return .denied
                }
            }
            return .notAvailable
        #else
            return .notAvailable
        #endif
    }

    private func checkAccessibilityStatus() -> PermissionStatus {
        #if os(macOS)
            return AXIsProcessTrusted() ? .authorized : .denied
        #else
            return .notAvailable
        #endif
    }

    private func checkScreenRecordingStatus() -> PermissionStatus {
        #if os(macOS)
            return CGPreflightScreenCaptureAccess() ? .authorized : .denied
        #else
            return .notAvailable
        #endif
    }

    private func checkInputMonitoringStatus() -> PermissionStatus {
        #if os(macOS)
            // Input monitoring uses same TCC as accessibility
            return AXIsProcessTrusted() ? .authorized : .denied
        #else
            return .notAvailable
        #endif
    }

    // MARK: - Request All Permissions

    func requestAllPermissions() async {
        // Request in order of importance
        await requestSpeechRecognition()
        await requestMicrophone()
        await requestNotifications()
        await requestContacts()
        await requestCalendar()
        await requestPhotos()
        await requestLocation()

        #if os(macOS)
            await requestFullDiskAccess()
        #endif

        hasCompletedOnboarding = true
        checkAllPermissions()
    }

    // MARK: - Individual Permission Requests

    func requestSpeechRecognition() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        speechRecognitionStatus = convertSpeechStatus(status)
    }

    func requestMicrophone() async {
        #if !os(macOS)
            let granted = await AVAudioApplication.requestRecordPermission()
            microphoneStatus = granted ? .authorized : .denied
        #else
            // macOS handles microphone permissions differently
            microphoneStatus = .authorized
        #endif
    }

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .providesAppNotificationSettings]
            )
            notificationsStatus = granted ? .authorized : .denied
        } catch {
            notificationsStatus = .denied
        }
    }

    func requestContacts() async {
        #if os(iOS) || os(macOS)
            let store = CNContactStore()
            do {
                let granted = try await store.requestAccess(for: .contacts)
                contactsStatus = granted ? .authorized : .denied
            } catch {
                contactsStatus = .denied
            }
        #endif
    }

    func requestCalendar() async {
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToEvents()
            calendarStatus = granted ? .authorized : .denied
        } catch {
            calendarStatus = .denied
        }
    }

    func requestPhotos() async {
        #if os(iOS) || os(macOS)
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            photosStatus = convertPhotoStatus(status)
        #endif
    }

    func requestLocation() async {
        #if os(iOS)
            let manager = CLLocationManager()
            manager.requestWhenInUseAuthorization()
            // Status will be updated via delegate
        #endif
    }

    func requestFullDiskAccess() async {
        #if os(macOS)
            // Full Disk Access can't be programmatically requested
            // User must grant it in System Settings
            fullDiskAccessStatus = checkFullDiskAccess()
        #endif
    }

    // MARK: - Check Current Status

    func checkAllPermissions() {
        checkSpeechRecognition()
        checkMicrophone()
        checkNotifications()
        checkContacts()
        checkCalendar()
        checkPhotos()
        checkLocation()

        #if os(macOS)
            fullDiskAccessStatus = checkFullDiskAccess()
        #endif
    }

    private func checkSpeechRecognition() {
        let status = SFSpeechRecognizer.authorizationStatus()
        speechRecognitionStatus = convertSpeechStatus(status)
    }

    private func checkMicrophone() {
        #if !os(macOS)
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                microphoneStatus = .authorized
            case .denied:
                microphoneStatus = .denied
            case .undetermined:
                microphoneStatus = .notDetermined
            @unknown default:
                microphoneStatus = .notDetermined
            }
        #else
            microphoneStatus = .authorized
        #endif
    }

    private func checkNotifications() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    notificationsStatus = .authorized
                case .denied:
                    notificationsStatus = .denied
                case .notDetermined:
                    notificationsStatus = .notDetermined
                case .ephemeral:
                    notificationsStatus = .authorized
                @unknown default:
                    notificationsStatus = .notDetermined
                }
            }
        }
    }

    private func checkContacts() {
        #if os(iOS) || os(macOS)
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized:
                contactsStatus = .authorized
            case .denied:
                contactsStatus = .denied
            case .notDetermined:
                contactsStatus = .notDetermined
            case .restricted:
                contactsStatus = .restricted
            case .limited:
                contactsStatus = .authorized
            @unknown default:
                contactsStatus = .notDetermined
            }
        #endif
    }

    private func checkCalendar() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            calendarStatus = .authorized
        case .denied:
            calendarStatus = .denied
        case .notDetermined:
            calendarStatus = .notDetermined
        case .restricted:
            calendarStatus = .restricted
        case .writeOnly:
            calendarStatus = .authorized
        @unknown default:
            calendarStatus = .notDetermined
        }
    }

    private func checkPhotos() {
        #if os(iOS) || os(macOS)
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            photosStatus = convertPhotoStatus(status)
        #endif
    }

    private func checkLocation() {
        #if os(iOS)
            let manager = CLLocationManager()
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                locationStatus = .authorized
            case .denied:
                locationStatus = .denied
            case .notDetermined:
                locationStatus = .notDetermined
            case .restricted:
                locationStatus = .restricted
            @unknown default:
                locationStatus = .notDetermined
            }
        #endif
    }

    private func checkFullDiskAccess() -> PermissionStatus {
        #if os(macOS)
            // Check if we can access a protected directory
            let testPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail")

            let canAccess = FileManager.default.isReadableFile(atPath: testPath.path)
            return canAccess ? .authorized : .denied
        #else
            return .authorized
        #endif
    }

    // MARK: - Request Permission

    /// Request a specific permission
    func requestPermission(for type: PermissionType) async -> PermissionStatus {
        let status: PermissionStatus

        switch type {
        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = granted ? .authorized : .denied
            cameraStatus = status

        case .microphone:
            #if os(macOS)
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                status = granted ? .authorized : .denied
            #else
                let granted = await AVAudioApplication.requestRecordPermission()
                status = granted ? .authorized : .denied
            #endif
            microphoneStatus = status

        case .photoLibrary:
            let phStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            status = convertPhotoStatus(phStatus)
            photosStatus = status

        case .photoLibraryAddOnly:
            let phStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            status = convertPhotoStatus(phStatus)

        case .contacts:
            do {
                let granted = try await CNContactStore().requestAccess(for: .contacts)
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }
            contactsStatus = status

        case .calendars:
            do {
                let granted = try await EKEventStore().requestFullAccessToEvents()
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }
            calendarStatus = status

        case .reminders:
            do {
                let granted = try await EKEventStore().requestFullAccessToReminders()
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }

        case .locationWhenInUse:
            CLLocationManager().requestWhenInUseAuthorization()
            status = .notDetermined // Updates via delegate

        case .locationAlways:
            CLLocationManager().requestAlwaysAuthorization()
            status = .notDetermined

        case .notifications:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }
            notificationsStatus = status

        case .criticalAlerts:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.criticalAlert])
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }

        case .speechRecognition:
            status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    switch authStatus {
                    case .authorized: continuation.resume(returning: .authorized)
                    case .denied: continuation.resume(returning: .denied)
                    case .restricted: continuation.resume(returning: .restricted)
                    case .notDetermined: continuation.resume(returning: .notDetermined)
                    @unknown default: continuation.resume(returning: .notDetermined)
                    }
                }
            }
            speechRecognitionStatus = status

        case .siri:
            #if os(iOS) || os(watchOS)
                status = await withCheckedContinuation { continuation in
                    INPreferences.requestSiriAuthorization { authStatus in
                        switch authStatus {
                        case .authorized: continuation.resume(returning: .authorized)
                        case .denied: continuation.resume(returning: .denied)
                        case .restricted: continuation.resume(returning: .restricted)
                        case .notDetermined: continuation.resume(returning: .notDetermined)
                        @unknown default: continuation.resume(returning: .notDetermined)
                        }
                    }
                }
                siriStatus = status
            #else
                status = .notAvailable
            #endif

        case .mediaLibrary:
            #if os(iOS)
                status = await withCheckedContinuation { continuation in
                    MPMediaLibrary.requestAuthorization { authStatus in
                        switch authStatus {
                        case .authorized: continuation.resume(returning: .authorized)
                        case .denied: continuation.resume(returning: .denied)
                        case .restricted: continuation.resume(returning: .restricted)
                        case .notDetermined: continuation.resume(returning: .notDetermined)
                        @unknown default: continuation.resume(returning: .notDetermined)
                        }
                    }
                }
            #else
                status = .notAvailable
            #endif

        case .accessibility:
            #if os(macOS)
                // Use string directly to avoid concurrency issues with kAXTrustedCheckOptionPrompt
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                let trusted = AXIsProcessTrustedWithOptions(options)
                status = trusted ? .authorized : .notDetermined
                accessibilityStatus = status
            #else
                status = .notAvailable
            #endif

        case .screenRecording:
            #if os(macOS)
                CGRequestScreenCaptureAccess()
                status = CGPreflightScreenCaptureAccess() ? .authorized : .denied
                screenRecordingStatus = status
            #else
                status = .notAvailable
            #endif

        default:
            status = .notAvailable
        }

        // Refresh all permissions after request
        await refreshAllPermissions()
        return status
    }

    // MARK: - Open Settings

    func openSystemSettings() {
        #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        #elseif os(macOS)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        #endif
    }

    /// Open settings for a specific permission type
    func openSettings(for type: PermissionType) {
        #if os(macOS)
            let urlString: String
            switch type {
            case .camera:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
            case .microphone:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            case .photoLibrary, .photoLibraryAddOnly:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
            case .contacts:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts"
            case .calendars:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
            case .reminders:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
            case .locationWhenInUse, .locationAlways:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
            case .speechRecognition:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
            case .accessibility:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .fullDiskAccess:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
            case .screenRecording:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .inputMonitoring:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            case .automation:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            case .bluetooth:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
            case .localNetwork:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"
            default:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy"
            }
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        #else
            openSystemSettings()
        #endif
    }

    // MARK: - Helper Methods

    private func convertSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func convertPhotoStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    // MARK: - Computed Properties

    var allPermissionsGranted: Bool {
        speechRecognitionStatus == .authorized &&
            microphoneStatus == .authorized &&
            notificationsStatus == .authorized
        // Don't require optional permissions
    }

    var criticalPermissionsDenied: [String] {
        var denied: [String] = []

        if speechRecognitionStatus == .denied {
            denied.append("Speech Recognition")
        }
        if microphoneStatus == .denied {
            denied.append("Microphone")
        }

        return denied
    }
}
