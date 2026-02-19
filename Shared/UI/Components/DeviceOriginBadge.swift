//
//  DeviceOriginBadge.swift
//  Thea
//
//  Compact badge showing the originating device for a message.
//  Displayed in the metadata row of MessageBubble when multi-device context is active.
//

import SwiftUI

// MARK: - Device Origin Badge

/// Small badge showing the device a message was sent from
struct DeviceOriginBadge: View {
    let deviceName: String
    let deviceType: String?

    /// Whether this message came from the current device
    let isCurrentDevice: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .medium))

            Text(shortDeviceName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isCurrentDevice ? Color.secondary : Color.theaPrimaryDefault)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            isCurrentDevice
                ? AnyShapeStyle(.ultraThinMaterial)
                : AnyShapeStyle(Color.theaPrimaryDefault.opacity(0.1))
        )
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sent from \(deviceName)")
    }

    // MARK: - Computed

    private var iconName: String {
        guard let raw = deviceType, let type = DeviceType(rawValue: raw) else {
            return "desktopcomputer"
        }
        return type.icon
    }

    /// Shorten long device names for compact display
    private var shortDeviceName: String {
        // Strip possessive patterns like "Alexis's "
        let cleaned = deviceName
            .replacingOccurrences(of: #"^.+'s\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^.+\u2019s\s+"#, with: "", options: .regularExpression)
        return cleaned.count > 20 ? String(cleaned.prefix(18)) + "\u{2026}" : cleaned
    }
}

// MARK: - Conversation Device Participants Bar

// periphery:ignore - Reserved: ConversationDeviceBar type reserved for future feature activation
/// Shows all devices that have participated in a conversation
struct ConversationDeviceBar: View {
    let messages: [Message]

    private var uniqueDevices: [(name: String, type: String?, isCurrent: Bool)] {
        var seen = Set<String>()
        var devices: [(name: String, type: String?, isCurrent: Bool)] = []
        let currentID = DeviceRegistry.shared.currentDevice.id

        for msg in messages {
            guard let id = msg.deviceID, let name = msg.deviceName, !seen.contains(id) else {
                continue
            }
            seen.insert(id)
            devices.append((name: name, type: msg.deviceType, isCurrent: id == currentID))
        }
        return devices
    }

    var body: some View {
        if uniqueDevices.count > 1 {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                ForEach(Array(uniqueDevices.enumerated()), id: \.offset) { _, device in
                    DeviceOriginBadge(
                        deviceName: device.name,
                        deviceType: device.type,
                        isCurrentDevice: device.isCurrent
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Device Origin Badge") {
        VStack(spacing: 12) {
            DeviceOriginBadge(
                deviceName: "Mac Studio",
                deviceType: "mac",
                isCurrentDevice: true
            )

            DeviceOriginBadge(
                deviceName: "Alexis\u{2019}s iPhone",
                deviceType: "iPhone",
                isCurrentDevice: false
            )

            DeviceOriginBadge(
                deviceName: "Alexis\u{2019}s MacBook Air",
                deviceType: "mac",
                isCurrentDevice: false
            )

            DeviceOriginBadge(
                deviceName: "iPad Pro",
                deviceType: "iPad",
                isCurrentDevice: false
            )
        }
        .padding()
    }
#endif
