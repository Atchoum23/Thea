// EventStoreTypesTests.swift
// Tests for EventStore persistence logic — base64 encoding, JSONL format, compaction

import Testing
import Foundation

// MARK: - Test Doubles

/// Minimal event type for testing serialization logic
private struct TestStoredEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: String
    let content: String

    init(id: UUID = UUID(), timestamp: Date = Date(), type: String = "test", content: String = "data") {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.content = content
    }
}

/// Mirrors EventStore's line serialization: JSON → base64 → line
private func serializeToLine(_ event: TestStoredEvent) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(event)
    return data.base64EncodedString()
}

/// Mirrors EventStore's deserialization: base64 → JSON → event
private func deserializeFromLine(_ line: String) throws -> TestStoredEvent {
    guard let data = Data(base64Encoded: line) else {
        throw TestEventError.invalidBase64
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(TestStoredEvent.self, from: data)
}

/// Mirrors EventStore's JSONL format: multiple lines, each base64-encoded
private func serializeToJSONL(_ events: [TestStoredEvent]) throws -> String {
    var lines: [String] = []
    for event in events {
        lines.append(try serializeToLine(event))
    }
    return lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
}

/// Mirrors EventStore's JSONL parsing
private func deserializeFromJSONL(_ content: String) throws -> [TestStoredEvent] {
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    var events: [TestStoredEvent] = []
    for line in lines {
        events.append(try deserializeFromLine(line))
    }
    return events
}

/// Mirrors EventStore's compaction: keep events >= cutoff date
private func compactEvents(
    _ content: String,
    before cutoff: Date
) throws -> String {
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    var keptLines: [String] = []

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    for line in lines {
        if let data = Data(base64Encoded: line),
           let event = try? decoder.decode(TestStoredEvent.self, from: data)
        {
            if event.timestamp >= cutoff {
                keptLines.append(line)
            }
        } else {
            // Keep lines we can't decode
            keptLines.append(line)
        }
    }
    return keptLines.joined(separator: "\n") + (keptLines.isEmpty ? "" : "\n")
}

/// Mirrors EventStore's eventCount logic
private func countEvents(_ content: String) -> Int {
    content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
}

private enum TestEventError: Error {
    case invalidBase64
}

// MARK: - Tests: Base64 Serialization

@Suite("Event Base64 Serialization")
struct EventBase64SerializationTests {
    @Test("Roundtrip — serialize then deserialize")
    func roundtrip() throws {
        let event = TestStoredEvent(content: "Hello, world!")
        let line = try serializeToLine(event)
        let decoded = try deserializeFromLine(line)
        #expect(decoded.id == event.id)
        #expect(decoded.content == event.content)
        #expect(decoded.type == event.type)
    }

    @Test("Base64 line is valid base64")
    func validBase64() throws {
        let event = TestStoredEvent()
        let line = try serializeToLine(event)
        #expect(Data(base64Encoded: line) != nil)
    }

    @Test("Line contains no newlines")
    func noNewlines() throws {
        let event = TestStoredEvent(content: "multi\nline\ncontent")
        let line = try serializeToLine(event)
        #expect(!line.contains("\n"))
    }

    @Test("Invalid base64 throws error")
    func invalidBase64Throws() {
        #expect(throws: TestEventError.self) {
            try deserializeFromLine("not-valid-base64!!!")
        }
    }

    @Test("Timestamp preserved through ISO8601")
    func timestampPreserved() throws {
        let now = Date(timeIntervalSince1970: 1707868800) // Fixed date
        let event = TestStoredEvent(timestamp: now)
        let line = try serializeToLine(event)
        let decoded = try deserializeFromLine(line)
        #expect(abs(decoded.timestamp.timeIntervalSince(now)) < 1.0)
    }

    @Test("Unicode content preserved")
    func unicodeContent() throws {
        let event = TestStoredEvent(content: "Héllo wörld 🌍 日本語 中文")
        let line = try serializeToLine(event)
        let decoded = try deserializeFromLine(line)
        #expect(decoded.content == "Héllo wörld 🌍 日本語 中文")
    }

    @Test("Empty content preserved")
    func emptyContent() throws {
        let event = TestStoredEvent(content: "")
        let line = try serializeToLine(event)
        let decoded = try deserializeFromLine(line)
        #expect(decoded.content.isEmpty)
    }
}

// MARK: - Tests: JSONL Format

@Suite("JSONL Format")
struct JSONLFormatTests {
    @Test("Empty array produces empty string")
    func emptyArray() throws {
        let result = try serializeToJSONL([])
        #expect(result.isEmpty)
    }

    @Test("Single event produces one line with trailing newline")
    func singleEvent() throws {
        let events = [TestStoredEvent(content: "solo")]
        let result = try serializeToJSONL(events)
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
        #expect(result.hasSuffix("\n"))
    }

    @Test("Multiple events produce one line each")
    func multipleEvents() throws {
        let events = (0..<5).map { TestStoredEvent(content: "event-\($0)") }
        let result = try serializeToJSONL(events)
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 5)
    }

    @Test("Roundtrip JSONL — serialize then deserialize multiple")
    func roundtripMultiple() throws {
        let events = [
            TestStoredEvent(type: "action", content: "clicked"),
            TestStoredEvent(type: "message", content: "hello"),
            TestStoredEvent(type: "error", content: "failed")
        ]
        let jsonl = try serializeToJSONL(events)
        let decoded = try deserializeFromJSONL(jsonl)
        #expect(decoded.count == 3)
        #expect(decoded[0].content == "clicked")
        #expect(decoded[1].content == "hello")
        #expect(decoded[2].content == "failed")
    }

    @Test("Event count from JSONL content")
    func eventCount() throws {
        let events = (0..<10).map { TestStoredEvent(content: "e\($0)") }
        let jsonl = try serializeToJSONL(events)
        #expect(countEvents(jsonl) == 10)
    }

    @Test("Event count of empty content is 0")
    func eventCountEmpty() {
        #expect(countEvents("") == 0)
    }

    @Test("Event count ignores empty lines")
    func eventCountIgnoresEmpty() {
        let content = "line1\n\nline2\n\n\nline3\n"
        #expect(countEvents(content) == 3)
    }
}

// MARK: - Tests: Compaction

@Suite("Event Compaction")
struct EventCompactionTests {
    @Test("Compaction keeps events after cutoff date")
    func keepsRecent() throws {
        let now = Date()
        let events = [
            TestStoredEvent(timestamp: now.addingTimeInterval(-30), content: "recent"),
            TestStoredEvent(timestamp: now, content: "newest")
        ]
        let jsonl = try serializeToJSONL(events)
        // Cutoff at now-50: both events are after cutoff, so both kept
        let compacted = try compactEvents(jsonl, before: now.addingTimeInterval(-50))
        let result = try deserializeFromJSONL(compacted)
        #expect(result.count == 2) // Both are >= cutoff
    }

    @Test("Compaction removes old events")
    func removesOld() throws {
        let now = Date()
        let events = [
            TestStoredEvent(timestamp: now.addingTimeInterval(-7200), content: "very old"),
            TestStoredEvent(timestamp: now.addingTimeInterval(-3600), content: "old"),
            TestStoredEvent(timestamp: now, content: "new")
        ]
        let jsonl = try serializeToJSONL(events)
        let compacted = try compactEvents(jsonl, before: now.addingTimeInterval(-1800))
        let result = try deserializeFromJSONL(compacted)
        #expect(result.count == 1) // Only "new" survives
        #expect(result.first?.content == "new")
    }

    @Test("Compaction of empty content")
    func compactEmpty() throws {
        let result = try compactEvents("", before: Date())
        #expect(result.isEmpty)
    }

    @Test("Compaction keeps undecodable lines")
    func keepsUndecodable() throws {
        // A line that's valid base64 but not valid JSON event
        let invalidLine = Data("not json".utf8).base64EncodedString()
        let now = Date()
        let validEvent = TestStoredEvent(timestamp: now, content: "valid")
        let validLine = try serializeToLine(validEvent)
        let content = invalidLine + "\n" + validLine + "\n"
        let compacted = try compactEvents(content, before: now.addingTimeInterval(-100))
        let lines = compacted.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 2) // Both kept (undecodable preserved)
    }

    @Test("Compaction with all events before cutoff")
    func allBeforeCutoff() throws {
        let past = Date().addingTimeInterval(-86400)
        let events = [
            TestStoredEvent(timestamp: past, content: "old1"),
            TestStoredEvent(timestamp: past, content: "old2")
        ]
        let jsonl = try serializeToJSONL(events)
        let compacted = try compactEvents(jsonl, before: Date())
        let result = try deserializeFromJSONL(compacted)
        #expect(result.isEmpty)
    }

    @Test("Compaction preserves event order")
    func preservesOrder() throws {
        let now = Date()
        let events = [
            TestStoredEvent(timestamp: now.addingTimeInterval(-10), content: "first"),
            TestStoredEvent(timestamp: now.addingTimeInterval(-5), content: "second"),
            TestStoredEvent(timestamp: now, content: "third")
        ]
        let jsonl = try serializeToJSONL(events)
        let compacted = try compactEvents(jsonl, before: now.addingTimeInterval(-100))
        let result = try deserializeFromJSONL(compacted)
        #expect(result.count == 3)
        #expect(result[0].content == "first")
        #expect(result[1].content == "second")
        #expect(result[2].content == "third")
    }
}

// MARK: - Tests: Storage Size Logic

@Suite("Storage Size")
struct StorageSizeTests {
    @Test("Events consume storage proportional to content")
    func storageGrows() throws {
        let small = try serializeToJSONL([TestStoredEvent(content: "x")])
        let large = try serializeToJSONL([TestStoredEvent(content: String(repeating: "x", count: 1000))])
        #expect(Data(large.utf8).count > Data(small.utf8).count)
    }

    @Test("Empty content has zero logical size")
    func emptySize() {
        #expect(countEvents("") == 0)
    }
}

// MARK: - Tests: Replay Filtering

@Suite("Event Replay Filtering")
struct EventReplayFilteringTests {
    @Test("Filter events since date")
    func filterSinceDate() throws {
        let now = Date()
        let events = [
            TestStoredEvent(timestamp: now.addingTimeInterval(-3600), content: "old"),
            TestStoredEvent(timestamp: now.addingTimeInterval(-1800), content: "middle"),
            TestStoredEvent(timestamp: now, content: "recent")
        ]
        let cutoff = now.addingTimeInterval(-2000)
        let filtered = events.filter { $0.timestamp >= cutoff }
        #expect(filtered.count == 2)
        #expect(filtered[0].content == "middle")
        #expect(filtered[1].content == "recent")
    }

    @Test("Filter with no events after cutoff")
    func noEventsAfterCutoff() {
        let now = Date()
        let events = [
            TestStoredEvent(timestamp: now.addingTimeInterval(-7200), content: "old1"),
            TestStoredEvent(timestamp: now.addingTimeInterval(-3600), content: "old2")
        ]
        let filtered = events.filter { $0.timestamp >= now }
        #expect(filtered.isEmpty)
    }

    @Test("Filter with all events after cutoff")
    func allEventsAfterCutoff() {
        let now = Date()
        let events = [
            TestStoredEvent(timestamp: now, content: "a"),
            TestStoredEvent(timestamp: now, content: "b")
        ]
        let filtered = events.filter { $0.timestamp >= now.addingTimeInterval(-100) }
        #expect(filtered.count == 2)
    }
}
