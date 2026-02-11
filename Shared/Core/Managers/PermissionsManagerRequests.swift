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

// MARK: - Permission Requests & Settings

extension PermissionsManager {
    // MARK: - Request Permission

    /// Request a specific permission — triggers the system prompt where possible,
    /// or opens System Settings for permissions that can only be granted manually.
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
            status = .notDetermined

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
                // On macOS, open System Settings instead
                openSettings(for: .mediaLibrary)
                status = .unknown
            #endif

        case .accessibility:
            #if os(macOS)
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

        // Permissions that can only be granted via System Settings
        case .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
             .localNetwork, .homeKit, .appManagement, .developerTools,
             .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
             .notes:
            openSettings(for: type)
            status = .unknown

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
