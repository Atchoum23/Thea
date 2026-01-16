import Contacts
import CoreLocation
import EventKit
import Foundation
import Photos
import Speech
@preconcurrency import UserNotifications

#if os(macOS)
import AppKit
#else
import AVFoundation
import UIKit
#endif

@MainActor
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    private(set) var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // Permission States
    private(set) var speechRecognitionStatus: PermissionStatus = .notDetermined
    private(set) var microphoneStatus: PermissionStatus = .notDetermined
    private(set) var notificationsStatus: PermissionStatus = .notDetermined
    private(set) var contactsStatus: PermissionStatus = .notDetermined
    private(set) var calendarStatus: PermissionStatus = .notDetermined
    private(set) var photosStatus: PermissionStatus = .notDetermined
    private(set) var locationStatus: PermissionStatus = .notDetermined
    private(set) var fullDiskAccessStatus: PermissionStatus = .notDetermined

    enum PermissionStatus: String {
        case notDetermined = "Not Determined"
        case denied = "Denied"
        case authorized = "Authorized"
        case restricted = "Restricted"
    }

    private init() {
        checkAllPermissions()
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
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
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
        switch AVAudioSession.sharedInstance().recordPermission {
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
