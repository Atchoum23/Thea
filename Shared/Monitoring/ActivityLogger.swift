//
//  ActivityLogger.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

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
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
        type: ActivityType,
        metadata: [String: Any] = [:]
    ) {
        let entry = ActivityLogEntry(
            type: type,
            timestamp: Date(),
            metadata: metadata.compactMapValues { $0 as? any Sendable }
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
                let decodedData = encryptionEnabled ? decrypt(data) : data
                if let decoded = try? JSONDecoder().decode([ActivityLogEntry].self, from: decodedData ?? data) {
                    existingEntries = decoded
                }
            }

            // Merge and save
            existingEntries.append(contentsOf: dayEntries)

            if let encoded = try? JSONEncoder().encode(existingEntries) {
                let dataToWrite = encryptionEnabled ? encrypt(encoded) : encoded
                try? dataToWrite?.write(to: filePath)
            }
        }
    }

    // MARK: - Encryption

    private func encrypt(_ data: Data) -> Data? {
        // Simple XOR encryption for demonstration
        // In production, use CryptoKit with proper key management
        let key: UInt8 = 0x42
        return Data(data.map { $0 ^ key })
    }

    private func decrypt(_ data: Data) -> Data? {
        // XOR is symmetric
        return encrypt(data)
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

        let decodedData = encryptionEnabled ? decrypt(data) : data
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
    public func getEntries(ofType type: ActivityType, for date: Date) async -> [ActivityLogEntry] {
        let entries = await getEntries(for: date)
        return entries.filter { $0.type == type }
    }

    // MARK: - Statistics

    /// Get daily statistics
    public func getDailyStats(for date: Date) async -> DailyActivityStats {
        let entries = await getEntries(for: date)

        var appUsage: [String: TimeInterval] = [:]
        var totalScreenTime: TimeInterval = 0
        var idlePeriods: Int = 0

        for entry in entries {
            switch entry.type {
            case .appUsage:
                if let app = entry.metadata["app"] as? String,
                   let duration = entry.duration {
                    appUsage[app, default: 0] += duration
                    totalScreenTime += duration
                }
            case .screenTime:
                if let duration = entry.duration {
                    totalScreenTime += duration
                }
            case .idleStart:
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
               fileDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Delete all logs
    public func deleteAllLogs() async {
        try? fileManager.removeItem(at: logsDirectory)
        await ensureLogsDirectory()
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
    public let type: ActivityType
    public let timestamp: Date
    public let duration: TimeInterval?
    public let metadata: [String: AnyCodable]

    public init(
        id: UUID = UUID(),
        type: ActivityType,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        metadata: [String: any Sendable] = [:]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
        self.metadata = metadata.compactMapValues { AnyCodable($0) }
    }
}

// MARK: - Activity Type

public enum ActivityType: String, Codable, Sendable, CaseIterable {
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
        case .appUsage: return "App Usage"
        case .appSwitch: return "App Switch"
        case .idleStart: return "Idle Started"
        case .idleEnd: return "Idle Ended"
        case .focusModeChange: return "Focus Mode"
        case .screenTime: return "Screen Time"
        case .inputSample: return "Input Activity"
        case .systemEvent: return "System Event"
        }
    }

    public var icon: String {
        switch self {
        case .appUsage: return "app"
        case .appSwitch: return "square.on.square"
        case .idleStart, .idleEnd: return "moon.zzz"
        case .focusModeChange: return "moon"
        case .screenTime: return "desktopcomputer"
        case .inputSample: return "keyboard"
        case .systemEvent: return "gear"
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

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable, Sendable {
    public let value: any Sendable

    public init(_ value: any Sendable) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            try container.encode(String(describing: value))
        }
    }
}
