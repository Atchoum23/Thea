//
//  ActivityLogger.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import CryptoKit
import Foundation

// MARK: - Activity Logger

/// Logs and stores activity data with encryption support
public actor ActivityLogger {
    public static let shared = ActivityLogger()

    // MARK: - Storage

    private var inMemoryBuffer: [ActivityLogEntry] = []
    private let bufferLimit = 100
    private let fileManager = FileManager.default

    // MARK: - Configuration

    private var encryptionEnabled = true
    private var retentionDays = 30

    // MARK: - Paths

    private var logsDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if app support not available
            return FileManager.default.temporaryDirectory.appendingPathComponent("Thea/ActivityLogs")
        }
        return appSupport.appendingPathComponent("Thea/ActivityLogs", isDirectory: true)
    }

    // MARK: - Initialization

    private init() {
        Task {
            await ensureLogsDirectory()
        }
    }

    private func ensureLogsDirectory() {
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Logging

    /// Log an activity entry
    public func log(_ entry: ActivityLogEntry) {
        inMemoryBuffer.append(entry)

        // Flush if buffer is full
        if inMemoryBuffer.count >= bufferLimit {
            Task {
                await flush()
            }
        }
    }

    /// Log a simple activity event
    public func logEvent(
        type: LoggingActivityType,
        metadata: [String: Any] = [:]
    ) {
        // Convert metadata to ActivityAnyCodable dictionary
        let codableMetadata = metadata.mapValues { ActivityAnyCodable($0) }

        let entry = ActivityLogEntry(
            type: type,
            timestamp: Date(),
            metadata: codableMetadata
        )
        log(entry)
    }

    // MARK: - Flush

    /// Flush buffer to disk
    public func flush() async {
        guard !inMemoryBuffer.isEmpty else { return }

        let entriesToFlush = inMemoryBuffer
        inMemoryBuffer.removeAll()

        await writeEntries(entriesToFlush)
    }

    private func writeEntries(_ entries: [ActivityLogEntry]) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Group entries by day
        var entriesByDay: [String: [ActivityLogEntry]] = [:]
        for entry in entries {
            let dayKey = dateFormatter.string(from: entry.timestamp)
            entriesByDay[dayKey, default: []].append(entry)
        }

        // Write each day's entries
        for (dayKey, dayEntries) in entriesByDay {
            let filePath = logsDirectory.appendingPathComponent("\(dayKey).json")

            // Load existing entries
            var existingEntries: [ActivityLogEntry] = []
            if let data = try? Data(contentsOf: filePath) {
                let decodedData = encryptionEnabled ? await decrypt(data) : data
                if let decoded = try? JSONDecoder().decode([ActivityLogEntry].self, from: decodedData ?? data) {
                    existingEntries = decoded
                }
            }

            // Merge and save
            existingEntries.append(contentsOf: dayEntries)

            if let encoded = try? JSONEncoder().encode(existingEntries) {
                let dataToWrite = encryptionEnabled ? await encrypt(encoded) : encoded
                try? dataToWrite?.write(to: filePath)
            }
        }
    }

    // MARK: - Encryption (AES-GCM via CryptoKit)

    private func encrypt(_ data: Data) async -> Data? {
        do {
            // Get encryption key from secure storage (Keychain)
            let keyData = try await MainActor.run {
                try SecureStorage.shared.getOrCreateEncryptionKey()
            }
            let symmetricKey = SymmetricKey(data: keyData)

            // AES-GCM encryption with authentication
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)

            // Return combined data (nonce + ciphertext + tag)
            return sealedBox.combined
        } catch {
            print("⚠️ ActivityLogger encryption failed: \(error)")
            return nil
        }
    }

    private func decrypt(_ data: Data) async -> Data? {
        do {
            // Get encryption key from secure storage (Keychain)
            let keyData = try await MainActor.run {
                try SecureStorage.shared.getOrCreateEncryptionKey()
            }
            let symmetricKey = SymmetricKey(data: keyData)

            // Restore sealed box from combined data
            let sealedBox = try AES.GCM.SealedBox(combined: data)

            // Decrypt and authenticate
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            print("⚠️ ActivityLogger decryption failed: \(error)")
            return nil
        }
    }

    // MARK: - Query

    /// Get entries for a specific date
    public func getEntries(for date: Date) async -> [ActivityLogEntry] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayKey = dateFormatter.string(from: date)

        let filePath = logsDirectory.appendingPathComponent("\(dayKey).json")

        guard let data = try? Data(contentsOf: filePath) else {
            return []
        }

        let decodedData = encryptionEnabled ? await decrypt(data) : data
        guard let decoded = try? JSONDecoder().decode([ActivityLogEntry].self, from: decodedData ?? data) else {
            return []
        }

        return decoded
    }

    /// Get entries for a date range
    public func getEntries(from startDate: Date, to endDate: Date) async -> [ActivityLogEntry] {
        var allEntries: [ActivityLogEntry] = []

        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            let dayEntries = await getEntries(for: currentDate)
            allEntries.append(contentsOf: dayEntries)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        return allEntries.sorted { $0.timestamp < $1.timestamp }
    }

    /// Get entries by type
    public func getEntries(ofType type: LoggingActivityType, for date: Date) async -> [ActivityLogEntry] {
        let entries = await getEntries(for: date)
        return entries.filter { $0.type == type }
    }

    // MARK: - Statistics

    /// Get daily statistics
    public func getDailyStats(for date: Date) async -> DailyActivityStats {
        let entries = await getEntries(for: date)

        var appUsage: [String: TimeInterval] = [:]
        var totalScreenTime: TimeInterval = 0
        var idlePeriods = 0

        for entry in entries {
            switch entry.type {
            case LoggingActivityType.appUsage:
                if let appCodable = entry.metadata["app"],
                   let app = appCodable.value as? String,
                   let duration = entry.duration
                {
                    appUsage[app, default: 0] += duration
                    totalScreenTime += duration
                }
            case LoggingActivityType.screenTime:
                if let duration = entry.duration {
                    totalScreenTime += duration
                }
            case LoggingActivityType.idleStart:
                idlePeriods += 1
            default:
                break
            }
        }

        return DailyActivityStats(
            date: date,
            totalScreenTime: totalScreenTime,
            appUsage: appUsage,
            idlePeriods: idlePeriods,
            entryCount: entries.count
        )
    }

    // MARK: - Cleanup

    /// Delete entries older than retention period
    public func cleanup() async {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let files = try? fileManager.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for file in files where file.pathExtension == "json" {
            let filename = file.deletingPathExtension().lastPathComponent
            if let fileDate = dateFormatter.date(from: filename),
               fileDate < cutoffDate
            {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Delete all logs
    public func deleteAllLogs() async {
        try? fileManager.removeItem(at: logsDirectory)
        ensureLogsDirectory()
        inMemoryBuffer.removeAll()
    }

    // MARK: - Configuration

    /// Update logger configuration
    public func configure(encryptionEnabled: Bool, retentionDays: Int) {
        self.encryptionEnabled = encryptionEnabled
        self.retentionDays = retentionDays
    }
}

// MARK: - Activity Log Entry

public struct ActivityLogEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: LoggingActivityType
    public let timestamp: Date
    public let duration: TimeInterval?
    public let metadata: [String: ActivityAnyCodable]

    public init(
        id: UUID = UUID(),
        type: LoggingActivityType,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        metadata: [String: ActivityAnyCodable] = [:]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
        self.metadata = metadata
    }

    /// Convenience initializer accepting Any values
    public init(
        id: UUID = UUID(),
        type: LoggingActivityType,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        rawMetadata: [String: Any]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
        metadata = rawMetadata.mapValues { ActivityAnyCodable($0) }
    }
}

// MARK: - Activity Type

public enum LoggingActivityType: String, Codable, Sendable, CaseIterable {
    case appUsage
    case appSwitch
    case idleStart
    case idleEnd
    case focusModeChange
    case screenTime
    case inputSample
    case systemEvent

    public var displayName: String {
        switch self {
        case .appUsage: "App Usage"
        case .appSwitch: "App Switch"
        case .idleStart: "Idle Started"
        case .idleEnd: "Idle Ended"
        case .focusModeChange: "Focus Mode"
        case .screenTime: "Screen Time"
        case .inputSample: "Input Activity"
        case .systemEvent: "System Event"
        }
    }

    public var icon: String {
        switch self {
        case .appUsage: "app"
        case .appSwitch: "square.on.square"
        case .idleStart, .idleEnd: "moon.zzz"
        case .focusModeChange: "moon"
        case .screenTime: "desktopcomputer"
        case .inputSample: "keyboard"
        case .systemEvent: "gear"
        }
    }
}

// MARK: - Daily Activity Stats

public struct DailyActivityStats: Sendable {
    public let date: Date
    public let totalScreenTime: TimeInterval
    public let appUsage: [String: TimeInterval]
    public let idlePeriods: Int
    public let entryCount: Int

    public var formattedScreenTime: String {
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    public var topApps: [(String, TimeInterval)] {
        appUsage.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}

// MARK: - ActivityAnyCodable Helper

/// A Sendable-compatible wrapper for codable primitive values
/// Uses an enum to avoid `any Sendable` existential type issues
public enum ActivityAnyCodable: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case null

    /// The underlying value
    public var value: Any {
        switch self {
        case let .string(v): v
        case let .int(v): v
        case let .double(v): v
        case let .bool(v): v
        case let .date(v): v
        case .null: NSNull()
        }
    }

    /// Initialize from any value, converting to appropriate case
    public init(_ value: Any) {
        switch value {
        case let str as String:
            self = .string(str)
        case let num as Int:
            self = .int(num)
        case let num as Double:
            self = .double(num)
        case let bool as Bool:
            self = .bool(bool)
        case let date as Date:
            self = .date(date)
        default:
            self = .string(String(describing: value))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let dateValue = try? container.decode(Date.self) {
            self = .date(dateValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(v):
            try container.encode(v)
        case let .int(v):
            try container.encode(v)
        case let .double(v):
            try container.encode(v)
        case let .bool(v):
            try container.encode(v)
        case let .date(v):
            try container.encode(v)
        case .null:
            try container.encodeNil()
        }
    }
}
