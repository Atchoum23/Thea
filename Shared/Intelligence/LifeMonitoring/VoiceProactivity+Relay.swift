// VoiceProactivity+Relay.swift
// THEA - Device Relay and Direct Messaging
// Created by Claude - February 2026
//
// Cross-device command relay (iPhone ↔ Mac) and direct message sending
// via AppleScript (macOS) or URL schemes (iOS).

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Messaging & Device Relay

extension VoiceProactivity {

    /// Check whether the current device can send a message directly.
    ///
    /// Returns `true` on macOS (always available) and `false` on iOS
    /// (conservative — prefers relay or voice confirmation).
    /// - Parameter platform: The target messaging platform.
    /// - Returns: `true` if direct send is available.
    func canSendDirectly(platform: VoiceRelayPlatform) async -> Bool {
        #if os(iOS)
        // On iOS, might need to check if unlocked
        return false // Conservative - always relay or confirm
        #else
        return true
        #endif
    }

    /// Send a message directly on the current device.
    ///
    /// On macOS, uses AppleScript to send via Messages.app.
    /// On iOS, opens the SMS URL scheme to pre-fill a message.
    /// - Parameter relay: The message relay descriptor.
    /// - Returns: `true` if the message was sent (or at least opened on iOS).
    func sendMessageDirectly(_ relay: MessageRelay) async -> Bool {
        #if os(macOS)
        // Use AppleScript to send iMessage on macOS
        let escapedMessage = relay.message.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedRecipient = relay.recipient.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(escapedRecipient)" of targetService
            send "\(escapedMessage)" to targetBuddy
        end tell
        """

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    continuation.resume(returning: error == nil)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
        #elseif os(iOS)
        // On iOS, use URL scheme to open Messages with pre-filled content
        let encodedBody = relay.message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRecipient = relay.recipient.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(encodedRecipient)&body=\(encodedBody)") else {
            return false
        }
        return await MainActor.run {
            UIApplication.shared.open(url)
            return true
        }
        #else
        return false
        #endif
    }

    /// Relay a command to the Mac via HTTP.
    ///
    /// Tries the Tailscale hostname first for internet connectivity,
    /// then falls back to `.local` mDNS for LAN access.
    /// - Parameter command: The device relay command to send.
    /// - Returns: `true` if the relay succeeded (HTTP 200).
    func relayThroughMac(_ command: DeviceRelayCommand) async -> Bool {
        guard configuration.macRelayEnabled, !configuration.macRelayHostname.isEmpty else {
            return false
        }

        let hostname = configuration.macRelayHostname
        let commandData: Data
        do {
            commandData = try JSONEncoder().encode(["command": String(describing: command)])
        } catch {
            return false
        }

        // Try Tailscale hostname first, then .local mDNS
        let hosts = [hostname, "\(hostname).local"]

        for host in hosts {
            guard let url = URL(string: "http://\(host):18789/relay") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 5)
            request.httpMethod = "POST"
            request.httpBody = commandData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let result = DeviceRelayResult(
                        success: true,
                        sourceDevice: ProcessInfo.processInfo.hostName,
                        targetDevice: hostname,
                        command: String(describing: command),
                        message: "Relayed via \(host)"
                    )
                    onDeviceRelayResult?(result)
                    return true
                }
            } catch {
                continue
            }
        }

        let result = DeviceRelayResult(
            success: false,
            sourceDevice: ProcessInfo.processInfo.hostName,
            targetDevice: hostname,
            command: String(describing: command),
            message: "Mac relay failed — host unreachable"
        )
        onDeviceRelayResult?(result)
        return false
    }

    /// Determine the messaging platform from a voice response.
    ///
    /// Matches the response's action string to a ``MessagingPlatform``,
    /// defaulting to `.iMessage` if no match is found.
    /// - Parameter response: The user's voice response.
    /// - Returns: The matched messaging platform.
    func determinePlatform(from response: VoiceResponse?) -> VoiceRelayPlatform {
        guard let action = response?.matchedExpectation?.action else {
            return .iMessage // Default
        }

        switch action {
        case "imessage": return .iMessage
        case "whatsapp": return .whatsApp
        case "telegram": return .telegram
        default: return .iMessage
        }
    }
}
