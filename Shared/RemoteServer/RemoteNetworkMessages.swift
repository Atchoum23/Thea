//
//  RemoteNetworkMessages.swift
//  Thea
//
//  Network proxy message types for remote server protocol
//

import Foundation

// MARK: - Network Proxy Messages

/// Request types for network proxy operations including HTTP requests, TCP connections, and LAN scans.
public enum NetworkProxyRequest: Codable, Sendable {
    case httpRequest(url: URL, method: String, headers: [String: String], body: Data?)
    case tcpConnect(host: String, port: Int)
    case localNetworkScan
}

public enum NetworkProxyResponse: Codable, Sendable {
    case httpResponse(statusCode: Int, headers: [String: String], body: Data)
    case tcpEstablished(connectionId: String)
    case tcpData(connectionId: String, data: Data)
    case tcpClosed(connectionId: String)
    case networkDevices([NetworkDevice])
    case error(String)
}

public struct NetworkDevice: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let ipAddress: String
    public let macAddress: String?
    public let deviceType: String?
    public let isOnline: Bool
    public let lastSeen: Date
    public let services: [NetworkService]

    public struct NetworkService: Codable, Sendable {
        public let name: String
        public let type: String
        public let port: Int
    }
}
