// ClipboardLogicTests.swift
// Tests for ClipboardHistoryManager paste stack, deduplication, search, and trim logic
// Standalone test doubles — no dependency on actual implementations

import Testing
import Foundation

// MARK: - Clipboard Test Doubles

/// Mirrors paste stack FIFO behavior
private final class TestPasteStack: @unchecked Sendable {
    var items: [String] = []

    func push(_ item: String) {
        items.append(item)
    }

    func pop() -> String? {
        guard !items.isEmpty else { return nil }
        return items.removeFirst()
    }

    func clear() {
        items.removeAll()
    }
}

/// Mirrors content hash for deduplication
private func contentHash(text: String?, imageSize: Int, fileNames: [String]) -> String {
    var components: [String] = []
    if let t = text { components.append("t:\(t.hashValue)") }
    if imageSize > 0 { components.append("i:\(imageSize)") }
    if !fileNames.isEmpty { components.append("f:\(fileNames.sorted().joined(separator: ","))") }
    return components.joined(separator: "|")
}

/// Mirrors trim history logic
private func trimHistory(
    entries: inout [(text: String, pinned: Bool, date: Date)],
    maxItems: Int,
    retentionDays: Int
) {
    let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
    // Remove old entries (skip pinned)
    entries.removeAll { !$0.pinned && $0.date < cutoff }
    // Remove excess by count (skip pinned)
    while entries.count > maxItems {
        if let idx = entries.lastIndex(where: { !$0.pinned }) {
            entries.remove(at: idx)
        } else {
            break
        }
    }
}

/// Mirrors search filter logic
private func searchFilter(
    entries: [(text: String, type: String, tags: [String], date: Date)],
    query: String?,
    contentType: String?,
    dateRange: ClosedRange<Date>?
) -> [(text: String, type: String, tags: [String], date: Date)] {
    entries.filter { entry in
        if let q = query, !q.isEmpty {
            let lq = q.lowercased()
            guard entry.text.lowercased().contains(lq)
                    || entry.tags.contains(where: { $0.lowercased().contains(lq) }) else {
                return false
            }
        }
        if let ct = contentType, entry.type != ct {
            return false
        }
        if let range = dateRange, !range.contains(entry.date) {
            return false
        }
        return true
    }
}

// MARK: - Clipboard Tests

@Suite("Paste Stack FIFO")
struct PasteStackTests {
    @Test("Empty stack returns nil")
    func emptyPop() {
        let stack = TestPasteStack()
        #expect(stack.pop() == nil)
    }

    @Test("FIFO order — first in, first out")
    func fifoOrder() {
        let stack = TestPasteStack()
        stack.push("first")
        stack.push("second")
        stack.push("third")
        #expect(stack.pop() == "first")
        #expect(stack.pop() == "second")
        #expect(stack.pop() == "third")
        #expect(stack.pop() == nil)
    }

    @Test("Clear empties stack")
    func clearStack() {
        let stack = TestPasteStack()
        stack.push("a")
        stack.push("b")
        stack.clear()
        #expect(stack.pop() == nil)
        #expect(stack.items.isEmpty)
    }

    @Test("Push after pop works correctly")
    func pushAfterPop() {
        let stack = TestPasteStack()
        stack.push("first")
        _ = stack.pop()
        stack.push("second")
        #expect(stack.pop() == "second")
    }
}

@Suite("Content Hash Deduplication")
struct ContentHashTests {
    @Test("Same text produces same hash")
    func sameTextSameHash() {
        let h1 = contentHash(text: "hello", imageSize: 0, fileNames: [])
        let h2 = contentHash(text: "hello", imageSize: 0, fileNames: [])
        #expect(h1 == h2)
    }

    @Test("Different text produces different hash")
    func differentTextDifferentHash() {
        let h1 = contentHash(text: "hello", imageSize: 0, fileNames: [])
        let h2 = contentHash(text: "world", imageSize: 0, fileNames: [])
        #expect(h1 != h2)
    }

    @Test("Image size included in hash")
    func imageSizeInHash() {
        let h1 = contentHash(text: nil, imageSize: 1024, fileNames: [])
        let h2 = contentHash(text: nil, imageSize: 2048, fileNames: [])
        #expect(h1 != h2)
    }

    @Test("File names sorted for consistency")
    func fileNamesSorted() {
        let h1 = contentHash(text: nil, imageSize: 0, fileNames: ["b.txt", "a.txt"])
        let h2 = contentHash(text: nil, imageSize: 0, fileNames: ["a.txt", "b.txt"])
        #expect(h1 == h2)
    }

    @Test("Nil text different from empty text")
    func nilVsEmpty() {
        let h1 = contentHash(text: nil, imageSize: 0, fileNames: [])
        let h2 = contentHash(text: "", imageSize: 0, fileNames: [])
        #expect(h1 != h2)
    }
}

@Suite("Search Filter")
struct ClipboardSearchFilterTests {
    let now = Date()
    var entries: [(text: String, type: String, tags: [String], date: Date)] {
        [
            ("Hello world", "text", ["greeting"], now),
            ("Swift code", "code", ["programming", "swift"], now),
            ("Image file", "image", [], now.addingTimeInterval(-86400)),
            ("Secret key", "text", ["sensitive"], now.addingTimeInterval(-172800))
        ]
    }

    @Test("No filter returns all")
    func noFilter() {
        let result = searchFilter(entries: entries, query: nil, contentType: nil, dateRange: nil)
        #expect(result.count == 4)
    }

    @Test("Query filter — case insensitive")
    func queryFilterCaseInsensitive() {
        let result = searchFilter(entries: entries, query: "hello", contentType: nil, dateRange: nil)
        #expect(result.count == 1)
        #expect(result.first?.text == "Hello world")
    }

    @Test("Query filter by tag")
    func queryFilterTag() {
        let result = searchFilter(entries: entries, query: "swift", contentType: nil, dateRange: nil)
        #expect(result.count == 1)
        #expect(result.first?.text == "Swift code")
    }

    @Test("Content type filter")
    func contentTypeFilter() {
        let result = searchFilter(entries: entries, query: nil, contentType: "text", dateRange: nil)
        #expect(result.count == 2)
    }

    @Test("Date range filter")
    func dateRangeFilter() {
        let range = now.addingTimeInterval(-100)...now.addingTimeInterval(100)
        let result = searchFilter(entries: entries, query: nil, contentType: nil, dateRange: range)
        #expect(result.count == 2) // Only "today" entries
    }

    @Test("Combined filters — AND logic")
    func combinedFilters() {
        let result = searchFilter(entries: entries, query: "key", contentType: "text", dateRange: nil)
        #expect(result.count == 1)
        #expect(result.first?.text == "Secret key")
    }

    @Test("No match returns empty")
    func noMatch() {
        let result = searchFilter(entries: entries, query: "nonexistent", contentType: nil, dateRange: nil)
        #expect(result.isEmpty)
    }

    @Test("Empty query returns all")
    func emptyQuery() {
        let result = searchFilter(entries: entries, query: "", contentType: nil, dateRange: nil)
        #expect(result.count == 4)
    }
}

@Suite("Trim History Logic")
struct TrimHistoryTests {
    @Test("Trim excess by count — keeps first N, removes non-pinned")
    func trimByCount() {
        var entries: [(text: String, pinned: Bool, date: Date)] = [
            ("a", false, Date()),
            ("b", false, Date()),
            ("c", false, Date()),
            ("d", false, Date()),
            ("e", false, Date())
        ]
        trimHistory(entries: &entries, maxItems: 3, retentionDays: 365)
        #expect(entries.count == 3)
    }

    @Test("Pinned entries survive trim")
    func pinnedSurvive() {
        var entries: [(text: String, pinned: Bool, date: Date)] = [
            ("a", true, Date()),
            ("b", false, Date()),
            ("c", true, Date()),
            ("d", false, Date()),
            ("e", false, Date())
        ]
        trimHistory(entries: &entries, maxItems: 2, retentionDays: 365)
        // 2 pinned + need to reach maxItems=2, but pinned can't be removed
        // So we end up with at least 2 pinned
        let pinned = entries.filter(\.pinned)
        #expect(pinned.count == 2)
    }

    @Test("Old entries removed by retention")
    func retentionRemoval() {
        let old = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        var entries: [(text: String, pinned: Bool, date: Date)] = [
            ("recent", false, Date()),
            ("old", false, old)
        ]
        trimHistory(entries: &entries, maxItems: 100, retentionDays: 30)
        #expect(entries.count == 1)
        #expect(entries.first?.text == "recent")
    }

    @Test("Old pinned entries not removed")
    func oldPinnedKept() {
        let old = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        var entries: [(text: String, pinned: Bool, date: Date)] = [
            ("old pinned", true, old),
            ("old unpinned", false, old)
        ]
        trimHistory(entries: &entries, maxItems: 100, retentionDays: 30)
        #expect(entries.count == 1)
        #expect(entries.first?.text == "old pinned")
    }

    @Test("Empty entries not affected")
    func emptyEntries() {
        var entries: [(text: String, pinned: Bool, date: Date)] = []
        trimHistory(entries: &entries, maxItems: 10, retentionDays: 30)
        #expect(entries.isEmpty)
    }
}
