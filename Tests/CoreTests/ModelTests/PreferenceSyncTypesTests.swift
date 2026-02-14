// PreferenceSyncTypesTests.swift
// Tests for PreferenceSyncEngine pure logic: device class compatibility,
// scope resolution, key mapping, preference lookup.

import Foundation
import XCTest

// MARK: - Mirrored Types

fileprivate enum TheaDeviceClass: String, CaseIterable, Codable, Sendable {
    case mac
    case iPhone
    case iPad
    case appleTV
    case appleWatch

    func sharesSyncGroup(with other: TheaDeviceClass) -> Bool {
        switch (self, other) {
        case (.mac, .mac): true
        case (.iPhone, .iPad), (.iPad, .iPhone): true
        case (.iPhone, .iPhone): true
        case (.iPad, .iPad): true
        case (.appleTV, .appleTV): true
        case (.appleWatch, .appleWatch): true
        case (.appleWatch, .iPhone), (.iPhone, .appleWatch): true
        default: false
        }
    }

    var displayName: String {
        switch self {
        case .mac: "Mac"
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .appleTV: "Apple TV"
        case .appleWatch: "Apple Watch"
        }
    }
}

fileprivate enum SyncScope: String, CaseIterable, Codable, Sendable {
    case universal
    case deviceClass
    case deviceLocal

    var displayName: String {
        switch self {
        case .universal: "All Devices"
        case .deviceClass: "Same Device Type"
        case .deviceLocal: "This Device Only"
        }
    }

    var explanation: String {
        switch self {
        case .universal: "Synced to all devices"
        case .deviceClass: "Synced to devices of the same type"
        case .deviceLocal: "Not synced"
        }
    }
}

fileprivate enum SyncCategory: String, CaseIterable, Codable, Sendable {
    case appearance
    case aiProviders
    case behavior
    case privacy
    case notifications
    case advanced
    case experimental

    var displayName: String {
        switch self {
        case .appearance: "Appearance"
        case .aiProviders: "AI Providers"
        case .behavior: "Behavior"
        case .privacy: "Privacy"
        case .notifications: "Notifications"
        case .advanced: "Advanced"
        case .experimental: "Experimental"
        }
    }

    var icon: String {
        switch self {
        case .appearance: "paintbrush"
        case .aiProviders: "brain"
        case .behavior: "gearshape"
        case .privacy: "lock.shield"
        case .notifications: "bell"
        case .advanced: "wrench.and.screwdriver"
        case .experimental: "flask"
        }
    }

    var defaultScope: SyncScope {
        switch self {
        case .appearance: .universal
        case .aiProviders: .universal
        case .behavior: .universal
        case .privacy: .deviceLocal
        case .notifications: .deviceClass
        case .advanced: .deviceLocal
        case .experimental: .deviceLocal
        }
    }
}

fileprivate struct PreferenceDescriptor: Sendable {
    let key: String
    let category: SyncCategory
    let defaultScope: SyncScope
    let description: String
}

// MARK: - Cloud Key Mapping (mirrors PreferenceSyncEngine)

private func cloudKey(
    for localKey: String,
    scope: SyncScope,
    deviceClass: TheaDeviceClass
) -> String? {
    switch scope {
    case .universal:
        return "u.\(localKey)"
    case .deviceClass:
        return "dc.\(deviceClass.rawValue).\(localKey)"
    case .deviceLocal:
        return nil
    }
}

fileprivate struct ParsedCloudKey {
    let localKey: String
    let deviceClass: TheaDeviceClass?
    let scope: SyncScope
}

private func parseCloudKey(_ key: String) -> ParsedCloudKey? {
    if key.hasPrefix("u.") {
        let localKey = String(key.dropFirst(2))
        return ParsedCloudKey(localKey: localKey, deviceClass: nil, scope: .universal)
    } else if key.hasPrefix("dc.") {
        let parts = key.dropFirst(3).split(separator: ".", maxSplits: 1)
        guard parts.count == 2,
              let dc = TheaDeviceClass(rawValue: String(parts[0])) else {
            return nil
        }
        return ParsedCloudKey(
            localKey: String(parts[1]),
            deviceClass: dc,
            scope: .deviceClass
        )
    }
    return nil
}

// MARK: - Scope Resolution

private func effectiveScope(
    key: String,
    descriptors: [PreferenceDescriptor],
    overrides: [SyncCategory: SyncScope]
) -> SyncScope {
    guard let descriptor = descriptors.first(where: { $0.key == key }) else {
        return .deviceLocal
    }
    return overrides[descriptor.category] ?? descriptor.defaultScope
}

// MARK: - Tests

final class DeviceClassTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(TheaDeviceClass.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TheaDeviceClass.mac.rawValue, "mac")
        XCTAssertEqual(TheaDeviceClass.iPhone.rawValue, "iPhone")
        XCTAssertEqual(TheaDeviceClass.iPad.rawValue, "iPad")
        XCTAssertEqual(TheaDeviceClass.appleTV.rawValue, "appleTV")
        XCTAssertEqual(TheaDeviceClass.appleWatch.rawValue, "appleWatch")
    }

    func testDisplayNames() {
        XCTAssertEqual(TheaDeviceClass.mac.displayName, "Mac")
        XCTAssertEqual(TheaDeviceClass.iPhone.displayName, "iPhone")
        XCTAssertEqual(TheaDeviceClass.iPad.displayName, "iPad")
        XCTAssertEqual(TheaDeviceClass.appleTV.displayName, "Apple TV")
        XCTAssertEqual(TheaDeviceClass.appleWatch.displayName, "Apple Watch")
    }

    func testMacSharesWithMac() {
        XCTAssertTrue(TheaDeviceClass.mac.sharesSyncGroup(with: .mac))
    }

    func testMacDoesNotShareWithiPhone() {
        XCTAssertFalse(TheaDeviceClass.mac.sharesSyncGroup(with: .iPhone))
    }

    func testMacDoesNotShareWithiPad() {
        XCTAssertFalse(TheaDeviceClass.mac.sharesSyncGroup(with: .iPad))
    }

    func testMacDoesNotShareWithTV() {
        XCTAssertFalse(TheaDeviceClass.mac.sharesSyncGroup(with: .appleTV))
    }

    func testMacDoesNotShareWithWatch() {
        XCTAssertFalse(TheaDeviceClass.mac.sharesSyncGroup(with: .appleWatch))
    }

    func testiPhoneSharesWithiPad() {
        XCTAssertTrue(TheaDeviceClass.iPhone.sharesSyncGroup(with: .iPad))
    }

    func testiPadSharesWithiPhone() {
        XCTAssertTrue(TheaDeviceClass.iPad.sharesSyncGroup(with: .iPhone))
    }

    func testiPhoneSharesWithiPhone() {
        XCTAssertTrue(TheaDeviceClass.iPhone.sharesSyncGroup(with: .iPhone))
    }

    func testiPadSharesWithiPad() {
        XCTAssertTrue(TheaDeviceClass.iPad.sharesSyncGroup(with: .iPad))
    }

    func testWatchSharesWithiPhone() {
        XCTAssertTrue(TheaDeviceClass.appleWatch.sharesSyncGroup(with: .iPhone))
    }

    func testiPhoneSharesWithWatch() {
        XCTAssertTrue(TheaDeviceClass.iPhone.sharesSyncGroup(with: .appleWatch))
    }

    func testWatchDoesNotShareWithMac() {
        XCTAssertFalse(TheaDeviceClass.appleWatch.sharesSyncGroup(with: .mac))
    }

    func testTVSharesWithTV() {
        XCTAssertTrue(TheaDeviceClass.appleTV.sharesSyncGroup(with: .appleTV))
    }

    func testTVDoesNotShareWithiPhone() {
        XCTAssertFalse(TheaDeviceClass.appleTV.sharesSyncGroup(with: .iPhone))
    }

    func testSharesSyncGroupIsSymmetric() {
        for a in TheaDeviceClass.allCases {
            for b in TheaDeviceClass.allCases {
                XCTAssertEqual(
                    a.sharesSyncGroup(with: b),
                    b.sharesSyncGroup(with: a),
                    "\(a)-\(b) should be symmetric"
                )
            }
        }
    }

    func testCodableRoundTrip() throws {
        for dc in TheaDeviceClass.allCases {
            let data = try JSONEncoder().encode(dc)
            let decoded = try JSONDecoder().decode(TheaDeviceClass.self, from: data)
            XCTAssertEqual(decoded, dc)
        }
    }
}

// MARK: - SyncScope Tests

final class SyncScopeTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(SyncScope.allCases.count, 3)
    }

    func testDisplayNames() {
        XCTAssertEqual(SyncScope.universal.displayName, "All Devices")
        XCTAssertEqual(SyncScope.deviceClass.displayName, "Same Device Type")
        XCTAssertEqual(SyncScope.deviceLocal.displayName, "This Device Only")
    }

    func testExplanations() {
        XCTAssertTrue(SyncScope.universal.explanation.contains("all devices"))
        XCTAssertTrue(SyncScope.deviceClass.explanation.contains("same type"))
        XCTAssertTrue(SyncScope.deviceLocal.explanation.contains("Not synced"))
    }

    func testCodableRoundTrip() throws {
        for scope in SyncScope.allCases {
            let data = try JSONEncoder().encode(scope)
            let decoded = try JSONDecoder().decode(SyncScope.self, from: data)
            XCTAssertEqual(decoded, scope)
        }
    }
}

// MARK: - SyncCategory Tests

final class SyncCategoryTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(SyncCategory.allCases.count, 7)
    }

    func testDisplayNamesNonEmpty() {
        for category in SyncCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category)")
        }
    }

    func testIconsNonEmpty() {
        for category in SyncCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category)")
        }
    }

    func testDefaultScopes() {
        XCTAssertEqual(SyncCategory.appearance.defaultScope, .universal)
        XCTAssertEqual(SyncCategory.aiProviders.defaultScope, .universal)
        XCTAssertEqual(SyncCategory.behavior.defaultScope, .universal)
        XCTAssertEqual(SyncCategory.privacy.defaultScope, .deviceLocal)
        XCTAssertEqual(SyncCategory.notifications.defaultScope, .deviceClass)
        XCTAssertEqual(SyncCategory.advanced.defaultScope, .deviceLocal)
        XCTAssertEqual(SyncCategory.experimental.defaultScope, .deviceLocal)
    }

    func testPrivacyIsAlwaysDeviceLocal() {
        XCTAssertEqual(SyncCategory.privacy.defaultScope, .deviceLocal)
    }

    func testAppearanceSyncsUniversally() {
        XCTAssertEqual(SyncCategory.appearance.defaultScope, .universal)
    }
}

// MARK: - Cloud Key Mapping Tests

final class CloudKeyMappingTests: XCTestCase {
    func testUniversalKeyEncoding() {
        let key = cloudKey(for: "theme", scope: .universal, deviceClass: .mac)
        XCTAssertEqual(key, "u.theme")
    }

    func testDeviceClassKeyEncodingMac() {
        let key = cloudKey(for: "fontSize", scope: .deviceClass, deviceClass: .mac)
        XCTAssertEqual(key, "dc.mac.fontSize")
    }

    func testDeviceClassKeyEncodingiPad() {
        let key = cloudKey(for: "fontSize", scope: .deviceClass, deviceClass: .iPad)
        XCTAssertEqual(key, "dc.iPad.fontSize")
    }

    func testDeviceLocalReturnsNil() {
        let key = cloudKey(for: "debugMode", scope: .deviceLocal, deviceClass: .mac)
        XCTAssertNil(key)
    }

    func testParseUniversalKey() {
        let parsed = parseCloudKey("u.theme")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.localKey, "theme")
        XCTAssertNil(parsed?.deviceClass)
        XCTAssertEqual(parsed?.scope, .universal)
    }

    func testParseDeviceClassKeyMac() {
        let parsed = parseCloudKey("dc.mac.fontSize")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.localKey, "fontSize")
        XCTAssertEqual(parsed?.deviceClass, .mac)
        XCTAssertEqual(parsed?.scope, .deviceClass)
    }

    func testParseDeviceClassKeyiPhone() {
        let parsed = parseCloudKey("dc.iPhone.hapticFeedback")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.localKey, "hapticFeedback")
        XCTAssertEqual(parsed?.deviceClass, .iPhone)
    }

    func testParseInvalidPrefix() {
        let parsed = parseCloudKey("x.theme")
        XCTAssertNil(parsed)
    }

    func testParseEmptyString() {
        let parsed = parseCloudKey("")
        XCTAssertNil(parsed)
    }

    func testParseDeviceClassInvalidDevice() {
        let parsed = parseCloudKey("dc.android.theme")
        XCTAssertNil(parsed)
    }

    func testParseDeviceClassMissingKey() {
        let parsed = parseCloudKey("dc.mac")
        XCTAssertNil(parsed)
    }

    func testRoundTripUniversal() {
        let original = "theme"
        let encoded = cloudKey(for: original, scope: .universal, deviceClass: .mac)!
        let parsed = parseCloudKey(encoded)!
        XCTAssertEqual(parsed.localKey, original)
        XCTAssertEqual(parsed.scope, .universal)
    }

    func testRoundTripDeviceClass() {
        let original = "fontSize"
        let device = TheaDeviceClass.iPad
        let encoded = cloudKey(for: original, scope: .deviceClass, deviceClass: device)!
        let parsed = parseCloudKey(encoded)!
        XCTAssertEqual(parsed.localKey, original)
        XCTAssertEqual(parsed.deviceClass, device)
    }

    func testKeyWithDotsInLocalKey() {
        let parsed = parseCloudKey("dc.mac.ai.provider.key")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.localKey, "ai.provider.key")
        XCTAssertEqual(parsed?.deviceClass, .mac)
    }
}

// MARK: - Scope Resolution Tests

final class ScopeResolutionTests: XCTestCase {
    fileprivate let descriptors: [PreferenceDescriptor] = [
        PreferenceDescriptor(
            key: "theme", category: .appearance,
            defaultScope: .universal, description: "App theme"
        ),
        PreferenceDescriptor(
            key: "fontSize", category: .appearance,
            defaultScope: .universal, description: "Font size"
        ),
        PreferenceDescriptor(
            key: "debugMode", category: .advanced,
            defaultScope: .deviceLocal, description: "Debug mode"
        ),
        PreferenceDescriptor(
            key: "notifications", category: .notifications,
            defaultScope: .deviceClass, description: "Notifications"
        ),
        PreferenceDescriptor(
            key: "apiKey", category: .privacy,
            defaultScope: .deviceLocal, description: "API key"
        ),
    ]

    func testDefaultScopeUsedWhenNoOverride() {
        let scope = effectiveScope(key: "theme", descriptors: descriptors, overrides: [:])
        XCTAssertEqual(scope, .universal)
    }

    func testOverrideTakesPrecedence() {
        let overrides: [SyncCategory: SyncScope] = [.appearance: .deviceLocal]
        let scope = effectiveScope(key: "theme", descriptors: descriptors, overrides: overrides)
        XCTAssertEqual(scope, .deviceLocal)
    }

    func testUnknownKeyDefaultsToDeviceLocal() {
        let scope = effectiveScope(key: "unknownKey", descriptors: descriptors, overrides: [:])
        XCTAssertEqual(scope, .deviceLocal)
    }

    func testOverrideDoesNotAffectOtherCategories() {
        let overrides: [SyncCategory: SyncScope] = [.appearance: .deviceLocal]
        let scope = effectiveScope(key: "notifications", descriptors: descriptors, overrides: overrides)
        XCTAssertEqual(scope, .deviceClass)
    }

    func testPrivacyDefaultsToDeviceLocal() {
        let scope = effectiveScope(key: "apiKey", descriptors: descriptors, overrides: [:])
        XCTAssertEqual(scope, .deviceLocal)
    }

    func testAdvancedDefaultsToDeviceLocal() {
        let scope = effectiveScope(key: "debugMode", descriptors: descriptors, overrides: [:])
        XCTAssertEqual(scope, .deviceLocal)
    }

    func testOverridePrivacyToUniversal() {
        let overrides: [SyncCategory: SyncScope] = [.privacy: .universal]
        let scope = effectiveScope(key: "apiKey", descriptors: descriptors, overrides: overrides)
        XCTAssertEqual(scope, .universal)
    }
}
