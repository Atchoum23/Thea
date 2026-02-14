// PermissionsTypesTests.swift
// Tests for standalone test doubles mirroring:
//   Shared/Core/Managers/PermissionsTypes.swift (PermissionStatus, PermissionCategory,
//   PermissionType, PermissionInfo)

import Foundation
import XCTest

// MARK: - Test Doubles — Permission Types

private enum TDPermissionStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined = "Not Set"
    case authorized = "Authorized"
    case denied = "Denied"
    case restricted = "Restricted"
    case limited = "Limited"
    case provisional = "Provisional"
    case notAvailable = "Not Available"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .notDetermined: "questionmark.circle"
        case .authorized: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .restricted: "lock.circle.fill"
        case .limited: "circle.lefthalf.filled"
        case .provisional: "clock.circle"
        case .notAvailable: "minus.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .notDetermined: "gray"
        case .authorized: "green"
        case .denied: "red"
        case .restricted: "orange"
        case .limited: "yellow"
        case .provisional: "blue"
        case .notAvailable: "gray"
        case .unknown: "gray"
        }
    }

    var canRequest: Bool { self == .notDetermined }
}

private enum TDPermissionCategory: String, CaseIterable, Sendable {
    case dataPrivacy = "Data & Privacy"
    case securityAccess = "Security & Access"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dataPrivacy: "lock.shield.fill"
        case .securityAccess: "gearshape.fill"
        }
    }
}

private enum TDPermissionType: String, CaseIterable, Sendable {
    // Data & Privacy
    case calendars = "Calendars"
    case contacts = "Contacts"
    case fullDiskAccess = "Full Disk Access"
    case homeKit = "Home"
    case mediaLibrary = "Media & Apple Music"
    case passkeys = "Passkeys Access for Web Browsers"
    case photoLibrary = "Photos"
    case reminders = "Reminders"
    case notes = "Notes"
    // Security & Access
    case accessibility = "Accessibility"
    case appManagement = "App Management"
    case automation = "Automation"
    case bluetooth = "Bluetooth"
    case camera = "Camera"
    case developerTools = "Developer Tools"
    case focusStatus = "Focus"
    case inputMonitoring = "Input Monitoring"
    case localNetwork = "Local Network"
    case microphone = "Microphone"
    case motionFitness = "Motion & Fitness"
    case remoteDesktop = "Remote Desktop"
    case screenRecording = "Screen & System Audio Recording"
    case speechRecognition = "Speech Recognition"
    // iOS-only
    case locationWhenInUse = "Location (When In Use)"
    case locationAlways = "Location (Always)"
    case notifications = "Notifications"
    case criticalAlerts = "Critical Alerts"
    case healthRead = "Health Data (Read)"
    case healthWrite = "Health Data (Write)"
    case photoLibraryAddOnly = "Photos (Add Only)"
    case siri = "Siri & Shortcuts"
    case faceID = "Face ID / Touch ID"

    var id: String { rawValue }

    var category: TDPermissionCategory {
        switch self {
        case .calendars, .contacts, .fullDiskAccess, .homeKit,
             .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes:
            return .dataPrivacy
        case .accessibility, .appManagement, .automation, .bluetooth,
             .camera, .developerTools, .focusStatus, .inputMonitoring,
             .localNetwork, .microphone, .motionFitness, .remoteDesktop,
             .screenRecording, .speechRecognition:
            return .securityAccess
        case .locationWhenInUse, .locationAlways:
            return .securityAccess
        case .notifications, .criticalAlerts:
            return .securityAccess
        case .healthRead, .healthWrite:
            return .dataPrivacy
        case .photoLibraryAddOnly:
            return .dataPrivacy
        case .siri:
            return .securityAccess
        case .faceID:
            return .securityAccess
        }
    }

    var canRequestProgrammatically: Bool {
        switch self {
        case .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
             .contacts, .calendars, .reminders, .notifications, .criticalAlerts,
             .speechRecognition, .locationWhenInUse, .locationAlways,
             .healthRead, .healthWrite, .siri, .faceID:
            return true
        case .accessibility, .screenRecording:
            return true
        case .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
             .localNetwork, .homeKit, .appManagement, .developerTools,
             .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
             .mediaLibrary, .notes:
            return false
        }
    }
}

private struct TDPermissionInfo: Sendable {
    let id: String
    let type: TDPermissionType
    var status: TDPermissionStatus
    let category: TDPermissionCategory

    var canRequest: Bool {
        status == .notDetermined && type.canRequestProgrammatically
    }

    var canOpenSettings: Bool {
        status == .denied || status == .restricted || status == .unknown
    }

    init(type: TDPermissionType, status: TDPermissionStatus) {
        self.id = type.rawValue
        self.type = type
        self.status = status
        self.category = type.category
    }
}

// MARK: - PermissionsTypesTests (26 tests)

final class PermissionsTypesTests: XCTestCase {

    // MARK: - PermissionStatus

    func testPermissionStatusAllCasesCount() {
        XCTAssertEqual(TDPermissionStatus.allCases.count, 8)
    }

    func testPermissionStatusRawValues() {
        XCTAssertEqual(TDPermissionStatus.notDetermined.rawValue, "Not Set")
        XCTAssertEqual(TDPermissionStatus.authorized.rawValue, "Authorized")
        XCTAssertEqual(TDPermissionStatus.denied.rawValue, "Denied")
        XCTAssertEqual(TDPermissionStatus.restricted.rawValue, "Restricted")
        XCTAssertEqual(TDPermissionStatus.limited.rawValue, "Limited")
        XCTAssertEqual(TDPermissionStatus.provisional.rawValue, "Provisional")
        XCTAssertEqual(TDPermissionStatus.notAvailable.rawValue, "Not Available")
        XCTAssertEqual(TDPermissionStatus.unknown.rawValue, "Unknown")
    }

    func testPermissionStatusUniqueRawValues() {
        let rawValues = TDPermissionStatus.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "PermissionStatus raw values must be unique")
    }

    func testPermissionStatusIcons() {
        XCTAssertEqual(TDPermissionStatus.notDetermined.icon, "questionmark.circle")
        XCTAssertEqual(TDPermissionStatus.authorized.icon, "checkmark.circle.fill")
        XCTAssertEqual(TDPermissionStatus.denied.icon, "xmark.circle.fill")
        XCTAssertEqual(TDPermissionStatus.restricted.icon, "lock.circle.fill")
        XCTAssertEqual(TDPermissionStatus.limited.icon, "circle.lefthalf.filled")
        XCTAssertEqual(TDPermissionStatus.provisional.icon, "clock.circle")
        XCTAssertEqual(TDPermissionStatus.notAvailable.icon, "minus.circle")
        XCTAssertEqual(TDPermissionStatus.unknown.icon, "questionmark.circle")
    }

    func testPermissionStatusColors() {
        XCTAssertEqual(TDPermissionStatus.notDetermined.color, "gray")
        XCTAssertEqual(TDPermissionStatus.authorized.color, "green")
        XCTAssertEqual(TDPermissionStatus.denied.color, "red")
        XCTAssertEqual(TDPermissionStatus.restricted.color, "orange")
        XCTAssertEqual(TDPermissionStatus.limited.color, "yellow")
        XCTAssertEqual(TDPermissionStatus.provisional.color, "blue")
        XCTAssertEqual(TDPermissionStatus.notAvailable.color, "gray")
        XCTAssertEqual(TDPermissionStatus.unknown.color, "gray")
    }

    func testPermissionStatusCanRequest() {
        XCTAssertTrue(TDPermissionStatus.notDetermined.canRequest)
        XCTAssertFalse(TDPermissionStatus.authorized.canRequest)
        XCTAssertFalse(TDPermissionStatus.denied.canRequest)
        XCTAssertFalse(TDPermissionStatus.restricted.canRequest)
        XCTAssertFalse(TDPermissionStatus.limited.canRequest)
        XCTAssertFalse(TDPermissionStatus.provisional.canRequest)
        XCTAssertFalse(TDPermissionStatus.notAvailable.canRequest)
        XCTAssertFalse(TDPermissionStatus.unknown.canRequest)
    }

    func testPermissionStatusCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in TDPermissionStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(TDPermissionStatus.self, from: data)
            XCTAssertEqual(decoded, status, "\(status) should survive Codable roundtrip")
        }
    }

    // MARK: - PermissionCategory

    func testPermissionCategoryAllCasesCount() {
        XCTAssertEqual(TDPermissionCategory.allCases.count, 2)
    }

    func testPermissionCategoryRawValues() {
        XCTAssertEqual(TDPermissionCategory.dataPrivacy.rawValue, "Data & Privacy")
        XCTAssertEqual(TDPermissionCategory.securityAccess.rawValue, "Security & Access")
    }

    func testPermissionCategoryIdEqualsRawValue() {
        for cat in TDPermissionCategory.allCases {
            XCTAssertEqual(cat.id, cat.rawValue)
        }
    }

    func testPermissionCategoryIcons() {
        XCTAssertEqual(TDPermissionCategory.dataPrivacy.icon, "lock.shield.fill")
        XCTAssertEqual(TDPermissionCategory.securityAccess.icon, "gearshape.fill")
    }

    // MARK: - PermissionType

    func testPermissionTypeAllCasesCount() {
        XCTAssertEqual(TDPermissionType.allCases.count, 32)
    }

    func testPermissionTypeUniqueRawValues() {
        let rawValues = TDPermissionType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "PermissionType raw values must be unique")
    }

    func testPermissionTypeDataPrivacyCategoryMapping() {
        let dataPrivacyTypes: [TDPermissionType] = [
            .calendars, .contacts, .fullDiskAccess, .homeKit,
            .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes,
            .healthRead, .healthWrite, .photoLibraryAddOnly
        ]
        for permType in dataPrivacyTypes {
            XCTAssertEqual(permType.category, .dataPrivacy,
                           "\(permType) should be in dataPrivacy category")
        }
    }

    func testPermissionTypeSecurityAccessCategoryMapping() {
        let securityTypes: [TDPermissionType] = [
            .accessibility, .appManagement, .automation, .bluetooth,
            .camera, .developerTools, .focusStatus, .inputMonitoring,
            .localNetwork, .microphone, .motionFitness, .remoteDesktop,
            .screenRecording, .speechRecognition,
            .locationWhenInUse, .locationAlways,
            .notifications, .criticalAlerts,
            .siri, .faceID
        ]
        for permType in securityTypes {
            XCTAssertEqual(permType.category, .securityAccess,
                           "\(permType) should be in securityAccess category")
        }
    }

    func testPermissionTypeProgrammaticallyRequestable() {
        let requestable: [TDPermissionType] = [
            .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
            .contacts, .calendars, .reminders, .notifications, .criticalAlerts,
            .speechRecognition, .locationWhenInUse, .locationAlways,
            .healthRead, .healthWrite, .siri, .faceID,
            .accessibility, .screenRecording
        ]
        for permType in requestable {
            XCTAssertTrue(permType.canRequestProgrammatically,
                          "\(permType) should be programmatically requestable")
        }
    }

    func testPermissionTypeNotProgrammaticallyRequestable() {
        let notRequestable: [TDPermissionType] = [
            .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
            .localNetwork, .homeKit, .appManagement, .developerTools,
            .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
            .mediaLibrary, .notes
        ]
        for permType in notRequestable {
            XCTAssertFalse(permType.canRequestProgrammatically,
                           "\(permType) should NOT be programmatically requestable")
        }
    }

    func testPermissionTypeIdEqualsRawValue() {
        for permType in TDPermissionType.allCases {
            XCTAssertEqual(permType.id, permType.rawValue)
        }
    }

    // MARK: - PermissionInfo

    func testPermissionInfoCreation() {
        let info = TDPermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertEqual(info.id, "Camera")
        XCTAssertEqual(info.type, .camera)
        XCTAssertEqual(info.status, .notDetermined)
        XCTAssertEqual(info.category, .securityAccess)
    }

    func testPermissionInfoCanRequestWhenNotDeterminedAndProgrammatic() {
        let info = TDPermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertTrue(info.canRequest, "Camera + notDetermined should be requestable")
    }

    func testPermissionInfoCannotRequestWhenAuthorized() {
        let info = TDPermissionInfo(type: .camera, status: .authorized)
        XCTAssertFalse(info.canRequest, "Already authorized should not be requestable")
    }

    func testPermissionInfoCannotRequestWhenNotProgrammatic() {
        let info = TDPermissionInfo(type: .fullDiskAccess, status: .notDetermined)
        XCTAssertFalse(info.canRequest,
                       "fullDiskAccess not programmatically requestable even when notDetermined")
    }

    func testPermissionInfoCanOpenSettingsWhenDenied() {
        let info = TDPermissionInfo(type: .microphone, status: .denied)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCanOpenSettingsWhenRestricted() {
        let info = TDPermissionInfo(type: .contacts, status: .restricted)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCanOpenSettingsWhenUnknown() {
        let info = TDPermissionInfo(type: .bluetooth, status: .unknown)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCannotOpenSettingsWhenAuthorized() {
        let info = TDPermissionInfo(type: .camera, status: .authorized)
        XCTAssertFalse(info.canOpenSettings)
    }

    func testPermissionInfoCannotOpenSettingsWhenNotDetermined() {
        let info = TDPermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertFalse(info.canOpenSettings)
    }

    func testPermissionInfoCategoryInheritsFromType() {
        let dataInfo = TDPermissionInfo(type: .contacts, status: .authorized)
        XCTAssertEqual(dataInfo.category, .dataPrivacy)

        let secInfo = TDPermissionInfo(type: .camera, status: .authorized)
        XCTAssertEqual(secInfo.category, .securityAccess)
    }
}
