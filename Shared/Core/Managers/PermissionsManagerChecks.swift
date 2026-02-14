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

// MARK: - Individual Status Checks (extracted for file_length compliance)

extension PermissionsManager {
    func checkCameraStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    func checkMicrophoneStatus() -> PermissionStatus {
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

    func checkPhotoLibraryStatus() -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .notDetermined
        }
    }

    func checkPhotoLibraryAddOnlyStatus() -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .notDetermined
        }
    }

    func checkContactsStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .notDetermined
        }
    }

    func checkCalendarStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .authorized
        case .writeOnly: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    func checkRemindersStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .authorized
        case .writeOnly: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    func checkLocationStatus() -> PermissionStatus {
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

    func checkHealthKitStatus() -> PermissionStatus {
        #if canImport(HealthKit) && !os(macOS) && !os(tvOS)
            guard HKHealthStore.isHealthDataAvailable() else {
                return .notAvailable
            }
            return .notDetermined
        #else
            return .notAvailable
        #endif
    }

    func checkMotionFitnessStatus() -> PermissionStatus {
        #if canImport(CoreMotion) && !os(macOS) && !os(tvOS)
            switch CMMotionActivityManager.authorizationStatus() {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            return .unknown
        #endif
    }

    func checkNotificationsStatus() async -> PermissionStatus {
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

    func checkCriticalAlertsStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.criticalAlertSetting {
        case .enabled: return .authorized
        case .disabled: return .denied
        case .notSupported: return .notAvailable
        @unknown default: return .notDetermined
        }
    }

    func checkMediaLibraryStatus() -> PermissionStatus {
        #if os(iOS)
            switch MPMediaLibrary.authorizationStatus() {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notDetermined
            }
        #else
            return .unknown
        #endif
    }

    func checkSpeechRecognitionStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    func checkSiriStatus() -> PermissionStatus {
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

    func checkBluetoothStatus() -> PermissionStatus {
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

    func checkFaceIDStatus() -> PermissionStatus {
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

    func checkAccessibilityStatus() -> PermissionStatus {
        #if os(macOS)
            return AXIsProcessTrusted() ? .authorized : .denied
        #else
            return .notAvailable
        #endif
    }

    func checkScreenRecordingStatus() -> PermissionStatus {
        #if os(macOS)
            return CGPreflightScreenCaptureAccess() ? .authorized : .denied
        #else
            return .notAvailable
        #endif
    }

    func checkInputMonitoringStatus() -> PermissionStatus {
        #if os(macOS)
            return AXIsProcessTrusted() ? .authorized : .denied
        #else
            return .notAvailable
        #endif
    }

    func checkDeveloperToolsStatus() -> PermissionStatus {
        #if os(macOS)
            let xcodePath = "/Library/Developer/CommandLineTools"
            let xcodeAppPath = "/Applications/Xcode.app"
            let hasTools = FileManager.default.fileExists(atPath: xcodePath) ||
                FileManager.default.fileExists(atPath: xcodeAppPath)
            return hasTools ? .authorized : .unknown
        #else
            return .notAvailable
        #endif
    }

    func checkFullDiskAccess() -> PermissionStatus {
        #if os(macOS)
            let testPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail")

            let canAccess = FileManager.default.isReadableFile(atPath: testPath.path)
            return canAccess ? .authorized : .denied
        #else
            return .authorized
        #endif
    }
}
