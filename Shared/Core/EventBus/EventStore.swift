// EventStore.swift
// Thea V2
//
// Persistent event storage with replay capability

import Foundation
import OSLog

/// Persistent storage for events with replay capability
public actor EventStore {
    public static let shared = EventStore()

    private let logger = Logger(subsystem: "com.thea.v2", category: "EventStore")
    private let fileManager = FileManager.default

    private var eventFileURL: URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if documents unavailable
            return fileManager.temporaryDirectory.appendingPathComponent("thea_events.jsonl")
        }
        return docs.appendingPathComponent("thea_events.jsonl")
    }

    private init() {}

    // MARK: - Storage

    /// Append an event to persistent storage
    public func store<E: TheaEvent>(_ event: E) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(event)
        let line = data.base64EncodedString() + "\n"

        if let lineData = line.data(using: .utf8) {
            if fileManager.fileExists(atPath: eventFileURL.path) {
                let handle = try FileHandle(forWritingTo: eventFileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
                try handle.close()
            } else {
                try lineData.write(to: eventFileURL)
            }
        }
    }

    // MARK: - Replay

    /// Replay all stored events
    public func replayAll(handler: (any TheaEvent) async -> Void) async throws {
        guard fileManager.fileExists(atPath: eventFileURL.path) else { return }

        let content = try String(contentsOf: eventFileURL, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for line in lines {
            if let data = Data(base64Encoded: line) {
                // Try to decode as each known event type
                if let event = try? decoder.decode(MessageEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(ActionEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(StateEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(ErrorEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(PerformanceEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(LearningEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(MemoryEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(VerificationEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(NavigationEvent.self, from: data) {
                    await handler(event)
                } else if let event = try? decoder.decode(LifecycleEvent.self, from: data) {
                    await handler(event)
                }
            }
        }
    }

    /// Replay events since a specific date
    public func replaySince(_ date: Date, handler: (any TheaEvent) async -> Void) async throws {
        try await replayAll { event in
            if event.timestamp >= date {
                await handler(event)
            }
        }
    }

    /// Get event count
    public func eventCount() -> Int {
        guard fileManager.fileExists(atPath: eventFileURL.path) else { return 0 }

        do {
            let content = try String(contentsOf: eventFileURL, encoding: .utf8)
            return content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        } catch {
            return 0
        }
    }

    // MARK: - Maintenance

    /// Clear all stored events
    public func clear() throws {
        if fileManager.fileExists(atPath: eventFileURL.path) {
            try fileManager.removeItem(at: eventFileURL)
        }
        logger.info("Event store cleared")
    }

    /// Get storage size in bytes
    public func storageSize() -> Int64 {
        guard let attrs = try? fileManager.attributesOfItem(atPath: eventFileURL.path) else {
            return 0
        }
        return attrs[.size] as? Int64 ?? 0
    }

    /// Compact the event store (remove events older than specified date)
    public func compact(before date: Date) async throws {
        guard fileManager.fileExists(atPath: eventFileURL.path) else { return }

        let content = try String(contentsOf: eventFileURL, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var keptLines: [String] = []

        for line in lines {
            if let data = Data(base64Encoded: line) {
                // Try to decode to get timestamp
                // This is a simplified approach - in production would use a more efficient method
                if let event = try? decoder.decode(MessageEvent.self, from: data) {
                    if event.timestamp >= date {
                        keptLines.append(line)
                    }
                } else {
                    // Keep events we can't decode
                    keptLines.append(line)
                }
            }
        }

        // Write compacted data
        let compactedContent = keptLines.joined(separator: "\n") + (keptLines.isEmpty ? "" : "\n")
        try compactedContent.write(to: eventFileURL, atomically: true, encoding: .utf8)

        logger.info("Compacted event store: \(lines.count) -> \(keptLines.count) events")
    }
}
