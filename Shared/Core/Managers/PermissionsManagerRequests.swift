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

#if canImport(HomeKit) && !os(macOS)
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

// MARK: - Permission Requests & Settings

extension PermissionsManager {
    // MARK: - Request Permission

    /// Request a specific permission — triggers the system prompt where possible,
    /// or opens System Settings for permissions that can only be granted manually.
    func requestPermission(for type: PermissionType) async -> PermissionStatus {
        let status: PermissionStatus

        switch type {
        case .camera, .microphone, .photoLibrary, .photoLibraryAddOnly:
            status = await requestMediaPermission(for: type)
        case .contacts, .calendars, .reminders:
            status = await requestDataPermission(for: type)
        case .locationWhenInUse, .locationAlways:
            status = requestLocationPermission(for: type)
        case .notifications, .criticalAlerts:
            status = await requestNotificationPermission(for: type)
        case .speechRecognition:
            status = await requestSpeechRecognitionPermission()
        case .siri:
            status = await requestSiriPermission()
        case .mediaLibrary:
            status = await requestMediaLibraryPermission()
        case .accessibility, .screenRecording:
            status = requestSecurityPermission(for: type)
        case .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
             .localNetwork, .homeKit, .appManagement, .developerTools,
             .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
             .notes:
            openSettings(for: type)
            status = .unknown
        default:
            status = .notAvailable
        }

        await refreshAllPermissions()
        return status
    }

    // MARK: - Media Permissions

    private func requestMediaPermission(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            let status: PermissionStatus = granted ? .authorized : .denied
            cameraStatus = status
            return status
        case .microphone:
            #if os(macOS)
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                let status: PermissionStatus = granted ? .authorized : .denied
            #else
                let granted = await AVAudioApplication.requestRecordPermission()
                let status: PermissionStatus = granted ? .authorized : .denied
            #endif
            microphoneStatus = status
            return status
        case .photoLibrary:
            let phStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            let status = convertPhotoStatus(phStatus)
            photosStatus = status
            return status
        case .photoLibraryAddOnly:
            let phStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return convertPhotoStatus(phStatus)
        default:
            return .notAvailable
        }
    }

    // MARK: - Data Permissions

    private func requestDataPermission(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .contacts:
            let status: PermissionStatus
            do {
                let granted = try await CNContactStore().requestAccess(for: .contacts)
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }
            contactsStatus = status
            return status
        case .calendars:
            let status: PermissionStatus
            do {
                let granted = try await EKEventStore().requestFullAccessToEvents()
                status = granted ? .authorized : .denied
            } catch {
                status = .denied
            }
            calendarStatus = status
            return status
        case .reminders:
            do {
                let granted = try await EKEventStore().requestFullAccessToReminders()
                return granted ? .authorized : .denied
            } catch {
                return .denied
            }
        default:
            return .notAvailable
        }
    }

    // MARK: - Location Permissions

    private func requestLocationPermission(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .locationWhenInUse:
            CLLocationManager().requestWhenInUseAuthorization()
        case .locationAlways:
            CLLocationManager().requestAlwaysAuthorization()
        default:
            break
        }
        return .notDetermined
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermission(for type: PermissionType) async -> PermissionStatus {
        let options: UNAuthorizationOptions = type == .criticalAlerts
            ? [.criticalAlert]
            : [.alert, .sound, .badge]

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: options)
            let status: PermissionStatus = granted ? .authorized : .denied
            if type == .notifications { notificationsStatus = status }
            return status
        } catch {
            if type == .notifications { notificationsStatus = .denied }
            return .denied
        }
    }

    // MARK: - Speech Recognition Permission

    private func requestSpeechRecognitionPermission() async -> PermissionStatus {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: self.convertSpeechStatus(authStatus))
            }
        }
        speechRecognitionStatus = status
        return status
    }

    // MARK: - Siri Permission

    private func requestSiriPermission() async -> PermissionStatus {
        #if os(iOS) || os(watchOS)
            let status = await withCheckedContinuation { continuation in
                INPreferences.requestSiriAuthorization { authStatus in
                    switch authStatus {
                    case .authorized: continuation.resume(returning: PermissionStatus.authorized)
                    case .denied: continuation.resume(returning: PermissionStatus.denied)
                    case .restricted: continuation.resume(returning: PermissionStatus.restricted)
                    case .notDetermined: continuation.resume(returning: PermissionStatus.notDetermined)
                    @unknown default: continuation.resume(returning: PermissionStatus.notDetermined)
                    }
                }
            }
            siriStatus = status
            return status
        #else
            return .notAvailable
        #endif
    }

    // MARK: - Media Library Permission

    private func requestMediaLibraryPermission() async -> PermissionStatus {
        #if os(iOS)
            return await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { authStatus in
                    switch authStatus {
                    case .authorized: continuation.resume(returning: PermissionStatus.authorized)
                    case .denied: continuation.resume(returning: PermissionStatus.denied)
                    case .restricted: continuation.resume(returning: PermissionStatus.restricted)
                    case .notDetermined: continuation.resume(returning: PermissionStatus.notDetermined)
                    @unknown default: continuation.resume(returning: PermissionStatus.notDetermined)
                    }
                }
            }
        #else
            openSettings(for: .mediaLibrary)
            return .unknown
        #endif
    }

    // MARK: - Security Permissions (macOS)

    private func requestSecurityPermission(for type: PermissionType) -> PermissionStatus {
        #if os(macOS)
            switch type {
            case .accessibility:
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                let trusted = AXIsProcessTrustedWithOptions(options)
                let status: PermissionStatus = trusted ? .authorized : .notDetermined
                accessibilityStatus = status
                return status
            case .screenRecording:
                CGRequestScreenCaptureAccess()
                let status: PermissionStatus = CGPreflightScreenCaptureAccess() ? .authorized : .denied
                screenRecordingStatus = status
                return status
            default:
                return .notAvailable
            }
        #else
            return .notAvailable
        #endif
    }

    // MARK: - Open Settings

    // periphery:ignore - Reserved: openSystemSettings() instance method reserved for future feature activation
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
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
            case .speechRecognition:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
            case .accessibility:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .fullDiskAccess:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
            case .screenRecording:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .inputMonitoring:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            case .automation:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            case .bluetooth:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
            case .localNetwork:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"
            case .appManagement:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles"
            case .developerTools:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_DevTools"
            case .focusStatus:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Focus"
            case .motionFitness:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion"
            case .remoteDesktop:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_RemoteDesktop"
            case .passkeys:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Passkeys"
            case .notes:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Notes"
            case .mediaLibrary:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Media"
            case .homeKit:
                urlString =
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_HomeKit"
            case .notifications:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications"
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
}
