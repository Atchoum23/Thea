//
//  TheaRemoteClient+Operations.swift
//  Thea
//
//  Screen, Input, File, and System operations extracted from TheaRemoteClient
//  Copyright © 2026. All rights reserved.
//

import Foundation

// MARK: - Screen Operations

extension TheaRemoteClient {
    /// Request a full screen capture
    public func captureScreen(quality: Float = 0.7, scale: Float = 0.5) async throws -> ScreenFrame {
        guard connectionState == .connected else {
            throw ClientError.notConnected
        }

        guard grantedPermissions.contains(.viewScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .screenRequest(.captureFullScreen(quality: quality, scale: scale)))

        let response = try await receiveWithTimeout(timeout: 30)

        guard case let .screenResponse(screenResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case let .frame(frame) = screenResponse else {
            if case let .error(error) = screenResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        lastScreenFrame = frame
        return frame
    }

    /// Start screen streaming
    public func startScreenStream(fps: Int = 30, quality: Float = 0.5, scale: Float = 0.5) async throws {
        guard connectionState == .connected else {
            throw ClientError.notConnected
        }

        guard grantedPermissions.contains(.viewScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .screenRequest(.startStream(fps: fps, quality: quality, scale: scale)))
    }

    /// Stop screen streaming
    public func stopScreenStream() async throws {
        try await send(message: .screenRequest(.stopStream))
    }
}

// MARK: - Input Operations

extension TheaRemoteClient {
    /// Move mouse to position
    public func moveMouse(to x: Int, _ y: Int) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.mouseMove(x: x, y: y)))
    }

    /// Click at position
    public func click(at x: Int, _ y: Int, button: InputRequest.MouseButton = .left, clickCount: Int = 1) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.mouseClick(x: x, y: y, button: button, clickCount: clickCount)))
    }

    /// Type text
    public func typeText(_ text: String) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.typeText(text)))
    }

    /// Press a key
    public func pressKey(keyCode: UInt16, modifiers: RemoteKeyModifiers = []) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.keyPress(keyCode: keyCode, modifiers: modifiers)))
    }

    /// Scroll at position
    public func scroll(at x: Int, _ y: Int, deltaX: Int, deltaY: Int) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.scroll(x: x, y: y, deltaX: deltaX, deltaY: deltaY)))
    }
}

// MARK: - File Operations

extension TheaRemoteClient {
    /// List directory contents
    public func listDirectory(_ path: String, recursive: Bool = false, showHidden: Bool = false) async throws -> [FileItem] {
        guard grantedPermissions.contains(.viewFiles) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .fileRequest(.list(path: path, recursive: recursive, showHidden: showHidden)))

        let response = try await receiveWithTimeout(timeout: 60)

        guard case let .fileResponse(fileResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case let .listing(items) = fileResponse else {
            if case let .error(error) = fileResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        return items
    }

    /// Download a file
    public func downloadFile(_ path: String) async throws -> Data {
        guard grantedPermissions.contains(.readFiles) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .fileRequest(.download(path: path)))

        let response = try await receiveWithTimeout(timeout: 300) // 5 minute timeout for large files

        guard case let .fileResponse(fileResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case let .data(data, _) = fileResponse else {
            if case let .error(error) = fileResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        return data
    }

    /// Upload a file
    public func uploadFile(_ data: Data, to path: String, overwrite: Bool = false) async throws {
        guard grantedPermissions.contains(.writeFiles) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .fileRequest(.upload(path: path, data: data, overwrite: overwrite)))

        let response = try await receiveWithTimeout(timeout: 300)

        guard case let .fileResponse(fileResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        if case let .error(error) = fileResponse {
            throw ClientError.serverError(error)
        }
    }
}

// MARK: - System Operations

extension TheaRemoteClient {
    /// Get system information
    public func getSystemInfo() async throws -> RemoteSystemInfo {
        try await send(message: .systemRequest(.getInfo))

        let response = try await receiveWithTimeout(timeout: 10)

        guard case let .systemResponse(systemResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case let .info(info) = systemResponse else {
            if case let .error(error) = systemResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        return info
    }

    /// Execute a command
    // swiftlint:disable:next function_parameter_count
    public func executeCommand(
        _ command: String,
        workingDirectory: String? = nil,
        timeout: TimeInterval = 60
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        guard grantedPermissions.contains(.executeCommands) else {
            throw ClientError.permissionDenied
        }

        try await send(
            message: .systemRequest(
                .executeCommand(command: command, workingDirectory: workingDirectory, timeout: timeout)
            )
        )

        let response = try await receiveWithTimeout(timeout: timeout + 10)

        guard case let .systemResponse(systemResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        switch systemResponse {
        case let .commandOutput(exitCode, stdout, stderr):
            return (exitCode, stdout, stderr)
        case let .confirmationRequired(action, confirmationId):
            throw ClientError.confirmationRequired(action: action, confirmationId: confirmationId)
        case let .error(error):
            throw ClientError.serverError(error)
        default:
            throw ClientError.unexpectedMessage
        }
    }

    /// Request system reboot
    public func reboot() async throws {
        guard grantedPermissions.contains(.systemControl) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .systemRequest(.reboot))

        let response = try await receiveWithTimeout(timeout: 60)

        guard case let .systemResponse(systemResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        if case let .error(error) = systemResponse {
            throw ClientError.serverError(error)
        }
    }
}
