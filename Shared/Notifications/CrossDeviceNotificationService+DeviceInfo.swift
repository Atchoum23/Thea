//
//  CrossDeviceNotificationService+DeviceInfo.swift
//  Thea
//
//  Device info helpers and registration loading for cross-device notifications
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Foundation
import OSLog

#if canImport(UIKit)
    import UIKit
#endif

#if os(watchOS)
    import WatchKit
#endif

// MARK: - Device Info Helpers

extension CrossDeviceNotificationService {
    func loadCurrentDeviceRegistration() async {
        // Try to load from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: "thea.notifications.deviceRegistration"),
           let registration = try? JSONDecoder().decode(CrossDeviceRegistration.self, from: data) {
            currentDeviceRegistration = registration
            return
        }

        // Check CloudKit for existing registration with this device name
        let deviceName = await getDeviceName()
        let predicate = NSPredicate(format: "deviceName == %@", deviceName)
        let query = CKQuery(recordType: "DeviceRegistration", predicate: predicate)

        do {
            let results = try await privateDatabase.records(matching: query)

            for (_, result) in results.matchResults {
                if case let .success(record) = result {
                    let registration = CrossDeviceRegistration(from: record)
                    currentDeviceRegistration = registration

                    // Cache locally
                    if let data = try? JSONEncoder().encode(registration) {
                        UserDefaults.standard.set(data, forKey: "thea.notifications.deviceRegistration")
                    }

                    return
                }
            }
        } catch {
            logger.warning("Failed to load device registration: \(error.localizedDescription)")
        }
    }

    @MainActor
    func getDeviceName() -> String {
        #if os(iOS)
            return UIDevice.current.name
        #elseif os(macOS)
            return Host.current().localizedName ?? "Mac"
        #elseif os(watchOS)
            return WKInterfaceDevice.current().name
        #elseif os(tvOS)
            return UIDevice.current.name
        #else
            return "Unknown Device"
        #endif
    }

    @MainActor
    func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier += String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    @MainActor
    func getOSVersion() -> String {
        #if os(iOS) || os(tvOS)
            return UIDevice.current.systemVersion
        #elseif os(macOS)
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #elseif os(watchOS)
            return WKInterfaceDevice.current().systemVersion
        #else
            return "Unknown"
        #endif
    }

    func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

}
