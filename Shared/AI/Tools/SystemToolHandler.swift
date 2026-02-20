// SystemToolHandler.swift
// Thea
//
// Tool handler for cross-platform system operations (B3)
// Covers: system_notification, system_clipboard_get/set, get_system_info

import Foundation
import os.log

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "ai.thea.app", category: "SystemToolHandler")

enum SystemToolHandler {

    // MARK: - system_notification

    @MainActor
    static func sendNotification(_ input: [String: Any]) async -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let title = input["title"] as? String ?? "Thea"
        let body = input["body"] as? String ?? ""
        logger.debug("system_notification: '\(title)'")

        #if os(macOS)
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
        #endif

        return ToolResult(toolUseId: id, content: "Notification sent: \(title)")
    }

    // MARK: - system_clipboard_get

    @MainActor
    static func getClipboard(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        #if os(macOS)
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        return ToolResult(toolUseId: id, content: text.isEmpty ? "(clipboard is empty)" : String(text.prefix(2000)))
        #else
        return ToolResult(toolUseId: id, content: "(clipboard not available on this platform)")
        #endif
    }

    // MARK: - system_clipboard_set

    @MainActor
    static func setClipboard(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let text = input["text"] as? String ?? ""
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.debug("system_clipboard_set: \(text.count) chars")
        return ToolResult(toolUseId: id, content: "Clipboard set (\(text.count) chars)")
        #else
        return ToolResult(toolUseId: id, content: "(clipboard not available on this platform)")
        #endif
    }

    // MARK: - get_system_info

    static func getSystemInfo(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        let dateStr = formatter.string(from: now)

        var info = [
            "Date/Time: \(dateStr)",
            "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Hostname: \(ProcessInfo.processInfo.hostName)",
            "Processors: \(ProcessInfo.processInfo.processorCount)",
            "Memory: \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)) GB"
        ]

        #if os(macOS)
        info.append("Platform: macOS")
        #elseif os(iOS)
        info.append("Platform: iOS")
        #elseif os(watchOS)
        info.append("Platform: watchOS")
        #elseif os(tvOS)
        info.append("Platform: tvOS")
        #endif

        return ToolResult(toolUseId: id, content: info.joined(separator: "\n"))
    }

    // MARK: - run_command (macOS only)

    #if os(macOS)
    static func runCommand(_ input: [String: Any]) async -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let command = input["command"] as? String ?? ""
        let workingDir = input["working_directory"] as? String

        guard !command.isEmpty else {
            return ToolResult(toolUseId: id, content: "No command provided.", isError: true)
        }

        // Security: block destructive commands
        let forbidden = ["rm -rf", "sudo rm", "format ", "mkfs", "dd if=", "> /dev/"]
        for blocked in forbidden {
            if command.lowercased().contains(blocked) {
                logger.warning("run_command: blocked dangerous command '\(command)'")
                return ToolResult(toolUseId: id, content: "Command blocked for safety: \(command)", isError: true)
            }
        }

        logger.debug("run_command: '\(command)'")
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            if let dir = workingDir {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                // Timeout after 30s
                let deadline = DispatchTime.now() + .seconds(30)
                DispatchQueue.global().asyncAfter(deadline: deadline) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
            } catch {
                return ToolResult(toolUseId: id, content: "Failed to run: \(error.localizedDescription)", isError: true)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus
            let prefix = exitCode == 0 ? "" : "[exit \(exitCode)] "
            return ToolResult(
                toolUseId: id,
                content: prefix + (output.isEmpty ? "(no output)" : String(output.prefix(4000))),
                isError: exitCode != 0
            )
        }.value
    }

    // MARK: - open_application

    @MainActor
    static func openApplication(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let name = input["name"] as? String ?? ""
        guard !name.isEmpty else {
            return ToolResult(toolUseId: id, content: "No application name provided.", isError: true)
        }
        let opened = NSWorkspace.shared.launchApplication(name)
        if opened {
            return ToolResult(toolUseId: id, content: "Opened \(name)")
        }
        // Try as full path
        if FileManager.default.fileExists(atPath: name) {
            let url = URL(fileURLWithPath: name)
            let opened2 = NSWorkspace.shared.open(url)
            return ToolResult(toolUseId: id, content: opened2 ? "Opened \(name)" : "Failed to open \(name)", isError: !opened2)
        }
        return ToolResult(toolUseId: id, content: "Could not find application '\(name)'", isError: true)
    }
    #endif
}
