// PermissionsAndClipboardTests.swift
// Tests for PermissionsManager types and permission status logic
// Standalone test doubles — no dependency on actual implementations
// Clipboard tests split to ClipboardLogicTests.swift

import Testing
import Foundation

// MARK: - Permissions Test Doubles

/// Mirrors permission categories from PermissionsManager
private enum TestPermissionCategory: String, CaseIterable, Sendable {
    case data
    case hardware
    case system
    case security
}

/// Mirrors permission types from PermissionsManager
private enum TestPermissionType: String, CaseIterable, Sendable {
    case camera
    case microphone
    case location
    case contacts
    case calendar
    case reminders
    case photos
    case files
    case accessibility
    case screenRecording
    case inputMonitoring
    case fullDiskAccess
    case notifications
    case bluetooth
    case speech
    case faceID

    var category: TestPermissionCategory {
        switch self {
        case .contacts, .calendar, .reminders, .photos, .files:
            return .data
        case .camera, .microphone, .bluetooth, .speech:
            return .hardware
        case .accessibility, .screenRecording, .inputMonitoring, .fullDiskAccess:
            return .system
        case .location, .notifications, .faceID:
            return .security
        }
    }

    var isRequestable: Bool {
        switch self {
        case .camera, .microphone, .contacts, .calendar, .reminders, .photos,
             .location, .notifications, .speech, .bluetooth, .faceID:
            return true
        case .accessibility, .screenRecording, .inputMonitoring, .fullDiskAccess, .files:
            return false
        }
    }

    var requiresSystemPreferences: Bool {
        !isRequestable
    }

    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .photos: return "Photos"
        case .files: return "Files & Folders"
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .inputMonitoring: return "Input Monitoring"
        case .fullDiskAccess: return "Full Disk Access"
        case .notifications: return "Notifications"
        case .bluetooth: return "Bluetooth"
        case .speech: return "Speech Recognition"
        case .faceID: return "Face ID"
        }
    }

    var icon: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "mic"
        case .location: return "location"
        case .contacts: return "person.crop.circle"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .photos: return "photo"
        case .files: return "folder"
        case .accessibility: return "accessibility"
        case .screenRecording: return "rectangle.inset.filled.and.person.filled"
        case .inputMonitoring: return "keyboard"
        case .fullDiskAccess: return "internaldrive"
        case .notifications: return "bell"
        case .bluetooth: return "bluetooth"
        case .speech: return "waveform"
        case .faceID: return "faceid"
        }
    }
}

/// Mirrors permission status
private enum TestPermissionStatus: String, CaseIterable, Sendable {
    case notDetermined
    case denied
    case authorized
    case restricted
    case limited
    case provisional
    case ephemeral
    case unknown

    var canRequest: Bool {
        self == .notDetermined
    }

    var isGranted: Bool {
        switch self {
        case .authorized, .limited, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    var icon: String {
        switch self {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        case .restricted: return "lock.circle.fill"
        case .limited: return "exclamationmark.circle"
        case .provisional: return "clock.circle"
        case .ephemeral: return "timer.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Permission Tests

@Suite("PermissionType Cases")
struct PermissionTypeCaseTests {
    @Test("All 16 permission types exist")
    func allCases() {
        #expect(TestPermissionType.allCases.count == 16)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestPermissionType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All have non-empty display names")
    func displayNames() {
        for perm in TestPermissionType.allCases {
            #expect(!perm.displayName.isEmpty, "\(perm) missing display name")
        }
    }

    @Test("All have non-empty icons")
    func icons() {
        for perm in TestPermissionType.allCases {
            #expect(!perm.icon.isEmpty, "\(perm) missing icon")
        }
    }
}

@Suite("Permission Categories")
struct PermissionCategoryTests {
    @Test("All 4 categories exist")
    func allCategories() {
        #expect(TestPermissionCategory.allCases.count == 4)
    }

    @Test("Data permissions include contacts, calendar, reminders, photos, files")
    func dataPermissions() {
        let data = TestPermissionType.allCases.filter { $0.category == .data }
        #expect(data.count == 5)
        #expect(data.contains(.contacts))
        #expect(data.contains(.calendar))
        #expect(data.contains(.reminders))
        #expect(data.contains(.photos))
        #expect(data.contains(.files))
    }

    @Test("Hardware permissions include camera, microphone, bluetooth, speech")
    func hardwarePermissions() {
        let hardware = TestPermissionType.allCases.filter { $0.category == .hardware }
        #expect(hardware.count == 4)
    }

    @Test("System permissions include accessibility, screen recording, input monitoring, full disk")
    func systemPermissions() {
        let system = TestPermissionType.allCases.filter { $0.category == .system }
        #expect(system.count == 4)
    }

    @Test("Security permissions include location, notifications, faceID")
    func securityPermissions() {
        let security = TestPermissionType.allCases.filter { $0.category == .security }
        #expect(security.count == 3)
    }

    @Test("Every permission has exactly one category")
    func exclusiveCategories() {
        for perm in TestPermissionType.allCases {
            let categories = TestPermissionCategory.allCases.filter { cat in
                perm.category == cat
            }
            #expect(categories.count == 1, "\(perm) should belong to exactly 1 category")
        }
    }
}

@Suite("Permission Requestability")
struct PermissionRequestabilityTests {
    @Test("Requestable permissions are 11")
    func requestableCount() {
        let requestable = TestPermissionType.allCases.filter(\.isRequestable)
        #expect(requestable.count == 11)
    }

    @Test("System preferences permissions are 5")
    func systemPrefsCount() {
        let sysprefs = TestPermissionType.allCases.filter(\.requiresSystemPreferences)
        #expect(sysprefs.count == 5)
    }

    @Test("Accessibility requires System Preferences")
    func accessibilityRequiresSysPrefs() {
        #expect(TestPermissionType.accessibility.requiresSystemPreferences)
    }

    @Test("Screen recording requires System Preferences")
    func screenRecordingRequiresSysPrefs() {
        #expect(TestPermissionType.screenRecording.requiresSystemPreferences)
    }

    @Test("Camera is requestable")
    func cameraRequestable() {
        #expect(TestPermissionType.camera.isRequestable)
    }

    @Test("Microphone is requestable")
    func microphoneRequestable() {
        #expect(TestPermissionType.microphone.isRequestable)
    }

    @Test("isRequestable and requiresSystemPreferences are mutually exclusive")
    func mutuallyExclusive() {
        for perm in TestPermissionType.allCases {
            #expect(perm.isRequestable != perm.requiresSystemPreferences,
                    "\(perm) should be either requestable or require sys prefs, not both")
        }
    }
}

@Suite("PermissionStatus")
struct PermissionStatusTests {
    @Test("All 8 statuses exist")
    func allStatuses() {
        #expect(TestPermissionStatus.allCases.count == 8)
    }

    @Test("Only notDetermined can request")
    func onlyNotDeterminedCanRequest() {
        for status in TestPermissionStatus.allCases {
            if status == .notDetermined {
                #expect(status.canRequest)
            } else {
                #expect(!status.canRequest)
            }
        }
    }

    @Test("Granted statuses: authorized, limited, provisional, ephemeral")
    func grantedStatuses() {
        #expect(TestPermissionStatus.authorized.isGranted)
        #expect(TestPermissionStatus.limited.isGranted)
        #expect(TestPermissionStatus.provisional.isGranted)
        #expect(TestPermissionStatus.ephemeral.isGranted)
    }

    @Test("Non-granted statuses")
    func nonGrantedStatuses() {
        #expect(!TestPermissionStatus.notDetermined.isGranted)
        #expect(!TestPermissionStatus.denied.isGranted)
        #expect(!TestPermissionStatus.restricted.isGranted)
        #expect(!TestPermissionStatus.unknown.isGranted)
    }

    @Test("All statuses have icons")
    func allHaveIcons() {
        for status in TestPermissionStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    @Test("Authorized has checkmark icon")
    func authorizedIcon() {
        #expect(TestPermissionStatus.authorized.icon.contains("checkmark"))
    }

    @Test("Denied has xmark icon")
    func deniedIcon() {
        #expect(TestPermissionStatus.denied.icon.contains("xmark"))
    }
}
