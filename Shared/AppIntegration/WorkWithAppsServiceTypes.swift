//
//  WorkWithAppsServiceTypes.swift
//  Thea
//
//  Supporting types for WorkWithAppsService
//

import Foundation

#if os(macOS)

// MARK: - Models

public struct AppDefinition: Identifiable, Sendable {
    public var id: String { bundleId }
    public let bundleId: String
    public let name: String
    public let icon: String
    public let capabilities: Set<AppCapability>
    public let actions: [String]
}

public enum AppCapability: String, Sendable {
    case fileOperations
    case navigation
    case selection
    case webBrowsing
    case readContent
    case writeContent
    case compose
    case search
    case terminal
}

public struct ConnectedApp: Identifiable, Sendable {
    public var id: String { definition.bundleId }
    public let definition: AppDefinition
    public var status: AppStatus
    public var processId: Int32?
}

public enum AppStatus: String, Sendable {
    case installed
    case running
    case notInstalled
}

public struct AppAction: Identifiable, Sendable {
    public let id: UUID
    public let appBundleId: String
    public let actionName: String
    public let parameters: [String: String]
    public let result: AppActionResult
    public let timestamp: Date
}

public struct AppActionResult: Sendable {
    public let success: Bool
    public var output: String?
    public var error: String?

    public init(success: Bool, output: String? = nil, error: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
    }
}

// MARK: - Errors

public enum WorkWithAppsError: Error, LocalizedError, Sendable {
    case accessibilityNotEnabled
    case appNotFound
    case appNotRunning
    case unsupportedAction(String)
    case missingParameter(String)
    case scriptError(String)
    case noActiveApp

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotEnabled:
            "Accessibility permissions are required. Please enable in System Settings > Privacy & Security > Accessibility."
        case .appNotFound:
            "Application not found"
        case .appNotRunning:
            "Application is not running"
        case let .unsupportedAction(action):
            "Unsupported action: \(action)"
        case let .missingParameter(param):
            "Missing required parameter: \(param)"
        case let .scriptError(message):
            "Script error: \(message)"
        case .noActiveApp:
            "No active app"
        }
    }
}

#else
    // iOS stub types
    public enum WorkWithAppsError: Error, LocalizedError {
        case notSupported

        public var errorDescription: String? {
            "Work with Apps is only available on macOS"
        }
    }
#endif
