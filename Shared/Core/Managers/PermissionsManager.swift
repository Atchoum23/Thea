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
    var speechRecognitionStatus: PermissionStatus = .notDetermined
    var microphoneStatus: PermissionStatus = .notDetermined
    var notificationsStatus: PermissionStatus = .notDetermined
    var contactsStatus: PermissionStatus = .notDetermined
    var calendarStatus: PermissionStatus = .notDetermined
    var photosStatus: PermissionStatus = .notDetermined
    var locationStatus: PermissionStatus = .notDetermined
    var fullDiskAccessStatus: PermissionStatus = .notDetermined
    var cameraStatus: PermissionStatus = .notDetermined
    var bluetoothStatus: PermissionStatus = .notDetermined
    var siriStatus: PermissionStatus = .notDetermined
    var healthStatus: PermissionStatus = .notDetermined
    var homeKitStatus: PermissionStatus = .notDetermined
    var accessibilityStatus: PermissionStatus = .notDetermined
    var screenRecordingStatus: PermissionStatus = .notDetermined

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

        let types = getPlatformPermissionTypes()

        for type in types {
            let status = await getPermissionStatus(for: type)
            permissions.append(PermissionInfo(type: type, status: status))
        }

        // Sort within each category alphabetically
        allPermissions = permissions.sorted { first, second in
            if first.category != second.category {
                return first.category == .dataPrivacy
            }
            return first.type.rawValue < second.type.rawValue
        }
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
                // Data & Privacy
                .calendars, .contacts, .fullDiskAccess, .homeKit,
                .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes,
                // Security & Access
                .accessibility, .appManagement, .automation, .bluetooth,
                .camera, .developerTools, .focusStatus, .inputMonitoring,
                .localNetwork, .microphone, .motionFitness, .remoteDesktop,
                .screenRecording, .speechRecognition
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

    // MARK: - Status Checks

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
            return .unknown // HomeKit has no status query API
        case .siri:
            return checkSiriStatus()
        case .bluetooth:
            return checkBluetoothStatus()
        case .localNetwork:
            return .unknown // No API to query
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
            return .unknown // Requires per-app check
        case .focusStatus:
            return .unknown // Requires Focus API
        case .appManagement:
            return .unknown // No query API
        case .developerTools:
            return checkDeveloperToolsStatus()
        case .remoteDesktop:
            return .unknown // No query API
        case .passkeys:
            return .unknown // No query API
        case .notes:
            return .unknown // No query API
        }
    }

    // Individual status checks are in PermissionsManagerChecks.swift

    // MARK: - Request All Permissions

    func requestAllPermissions() async {
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
        #endif
    }

    func requestFullDiskAccess() async {
        #if os(macOS)
            fullDiskAccessStatus = checkFullDiskAccess()
        #endif
    }

    // MARK: - Check Current Status (Legacy)

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
            let testPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail")

            let canAccess = FileManager.default.isReadableFile(atPath: testPath.path)
            return canAccess ? .authorized : .denied
        #else
            return .authorized
        #endif
    }

    // MARK: - Helper Methods

    func convertSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
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

    func convertPhotoStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
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
