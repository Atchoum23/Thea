//
//  RemoteMessages.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation

// MARK: - Remote Message Protocol

/// All messages exchanged between Thea remote server and clients
public enum RemoteMessage: Codable, Sendable {
    // Authentication
    case authChallenge(AuthChallenge)
    case authResponse(AuthResponse)
    case authSuccess(Set<RemotePermission>)
    case authFailure(String)

    // Screen sharing
    case screenRequest(ScreenRequest)
    case screenResponse(ScreenResponse)

    // Input control
    case inputRequest(InputRequest)
    case inputAck

    // File operations
    case fileRequest(FileRequest)
    case fileResponse(FileResponse)

    // System control
    case systemRequest(SystemRequest)
    case systemResponse(SystemResponse)

    // Network proxy
    case networkRequest(NetworkProxyRequest)
    case networkResponse(NetworkProxyResponse)

    // Clipboard sync
    case clipboardRequest(ClipboardRequest)
    case clipboardResponse(ClipboardResponse)

    // Session chat
    case chatMessage(ChatMessageData)

    // Annotations
    case annotationRequest(AnnotationRequest)

    // Recording
    case recordingRequest(RecordingRequest)
    case recordingResponse(RecordingResponse)

    // Audio streaming
    case audioRequest(AudioRequest)
    case audioResponse(AudioResponse)

    // Inventory
    case inventoryRequest(InventoryRequest)
    case inventoryResponse(InventoryResponse)

    // Inference relay (tvOS <-> macOS AI pipeline)
    case inferenceRelayRequest(Data)
    case inferenceRelayResponse(Data)

    // Connection management
    case ping
    case pong
    case disconnect
    case error(String)

    // Required permission for this message type
    public var requiredPermission: RemotePermission {
        switch self {
        case .screenRequest: .viewScreen
        case .inputRequest: .controlScreen
        case let .fileRequest(req):
            switch req {
            case .list, .info: .viewFiles
            case .read, .download: .readFiles
            case .write, .upload, .createDirectory, .move, .copy: .writeFiles
            case .delete: .deleteFiles
            }
        case let .systemRequest(req):
            switch req {
            case .getInfo, .getProcesses: .viewScreen
            case .executeCommand: .executeCommands
            default: .systemControl
            }
        case .networkRequest: .networkAccess
        case .clipboardRequest, .clipboardResponse: .controlScreen
        case .chatMessage: .viewScreen
        case .annotationRequest: .viewScreen
        case .recordingRequest, .recordingResponse: .viewScreen
        case .audioRequest, .audioResponse: .viewScreen
        case .inventoryRequest, .inventoryResponse: .viewScreen
        case .inferenceRelayRequest, .inferenceRelayResponse: .inferenceRelay
        default: .viewScreen
        }
    }
}

// MARK: - Message Serialization

public extension RemoteMessage {
    /// Encode message to data for transmission
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decode message from received data
    static func decode(from data: Data) throws -> RemoteMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteMessage.self, from: data)
    }
}
