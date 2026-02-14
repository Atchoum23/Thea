// PermissionsAndClipboardTests.swift
// Tests for PermissionsManager types and ClipboardHistoryManager logic
// Standalone test doubles — no dependency on actual implementations

import Testing
import Foundation

// MARK: - Permissions Test Doubles

/// Mirrors permission categories from PermissionsManager
private enum TestPermissionCategory: String, CaseIterable, Sendable {
    case data
    case hardware
    case system
    case security
}

/// Mirrors permission types from PermissionsManager
private enum TestPermissionType: String, CaseIterable, Sendable {
    case camera
    case microphone
    case location
    case contacts
    case calendar
    case reminders
    case photos
    case files
    case accessibility
    case screenRecording
    case inputMonitoring
    case fullDiskAccess
    case notifications
    case bluetooth
    case speech
    case faceID

    var category: TestPermissionCategory {
        switch self {
        case .contacts, .calendar, .reminders, .photos, .files:
            return .data
        case .camera, .microphone, .bluetooth, .speech:
            return .hardware
        case .accessibility, .screenRecording, .inputMonitoring, .fullDiskAccess:
            return .system
        case .location, .notifications, .faceID:
            return .security
        }
    }

    var isRequestable: Bool {
        switch self {
        case .camera, .microphone, .contacts, .calendar, .reminders, .photos,
             .location, .notifications, .speech, .bluetooth, .faceID:
            return true
        case .accessibility, .screenRecording, .inputMonitoring, .fullDiskAccess, .files:
            return false
        }
    }

    var requiresSystemPreferences: Bool {
        !isRequestable
    }

    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .location: return "Location"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .photos: return "Photos"
        case .files: return "Files & Folders"
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .inputMonitoring: return "Input Monitoring"
        case .fullDiskAccess: return "Full Disk Access"
        case .notifications: return "Notifications"
        case .bluetooth: return "Bluetooth"
        case .speech: return "Speech Recognition"
        case .faceID: return "Face ID"
        }
    }

    var icon: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "mic"
        case .location: return "location"
        case .contacts: return "person.crop.circle"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .photos: return "photo"
        case .files: return "folder"
        case .accessibility: return "accessibility"
        case .screenRecording: return "rectangle.inset.filled.and.person.filled"
        case .inputMonitoring: return "keyboard"
        case .fullDiskAccess: return "internaldrive"
        case .notifications: return "bell"
        case .bluetooth: return "bluetooth"
        case .speech: return "waveform"
        case .faceID: return "faceid"
        }
    }
}

/// Mirrors permission status
private enum TestPermissionStatus: String, CaseIterable, Sendable {
    case notDetermined
    case denied
    case authorized
    case restricted
    case limited
    case provisional
    case ephemeral
    case unknown

    var canRequest: Bool {
        self == .notDetermined
    }

    var isGranted: Bool {
        switch self {
        case .authorized, .limited, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    var icon: String {
        switch self {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        case .restricted: return "lock.circle.fill"
        case .limited: return "exclamationmark.circle"
        case .provisional: return "clock.circle"
        case .ephemeral: return "timer.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

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

// MARK: - Permission Tests

@Suite("PermissionType Cases")
struct PermissionTypeCaseTests {
    @Test("All 16 permission types exist")
    func allCases() {
        #expect(TestPermissionType.allCases.count == 16)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestPermissionType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All have non-empty display names")
    func displayNames() {
        for perm in TestPermissionType.allCases {
            #expect(!perm.displayName.isEmpty, "\(perm) missing display name")
        }
    }

    @Test("All have non-empty icons")
    func icons() {
        for perm in TestPermissionType.allCases {
            #expect(!perm.icon.isEmpty, "\(perm) missing icon")
        }
    }
}

@Suite("Permission Categories")
struct PermissionCategoryTests {
    @Test("All 4 categories exist")
    func allCategories() {
        #expect(TestPermissionCategory.allCases.count == 4)
    }

    @Test("Data permissions include contacts, calendar, reminders, photos, files")
    func dataPermissions() {
        let data = TestPermissionType.allCases.filter { $0.category == .data }
        #expect(data.count == 5)
        #expect(data.contains(.contacts))
        #expect(data.contains(.calendar))
        #expect(data.contains(.reminders))
        #expect(data.contains(.photos))
        #expect(data.contains(.files))
    }

    @Test("Hardware permissions include camera, microphone, bluetooth, speech")
    func hardwarePermissions() {
        let hardware = TestPermissionType.allCases.filter { $0.category == .hardware }
        #expect(hardware.count == 4)
    }

    @Test("System permissions include accessibility, screen recording, input monitoring, full disk")
    func systemPermissions() {
        let system = TestPermissionType.allCases.filter { $0.category == .system }
        #expect(system.count == 4)
    }

    @Test("Security permissions include location, notifications, faceID")
    func securityPermissions() {
        let security = TestPermissionType.allCases.filter { $0.category == .security }
        #expect(security.count == 3)
    }

    @Test("Every permission has exactly one category")
    func exclusiveCategories() {
        for perm in TestPermissionType.allCases {
            let categories = TestPermissionCategory.allCases.filter { cat in
                perm.category == cat
            }
            #expect(categories.count == 1, "\(perm) should belong to exactly 1 category")
        }
    }
}

@Suite("Permission Requestability")
struct PermissionRequestabilityTests {
    @Test("Requestable permissions are 11")
    func requestableCount() {
        let requestable = TestPermissionType.allCases.filter(\.isRequestable)
        #expect(requestable.count == 11)
    }

    @Test("System preferences permissions are 5")
    func systemPrefsCount() {
        let sysprefs = TestPermissionType.allCases.filter(\.requiresSystemPreferences)
        #expect(sysprefs.count == 5)
    }

    @Test("Accessibility requires System Preferences")
    func accessibilityRequiresSysPrefs() {
        #expect(TestPermissionType.accessibility.requiresSystemPreferences)
    }

    @Test("Screen recording requires System Preferences")
    func screenRecordingRequiresSysPrefs() {
        #expect(TestPermissionType.screenRecording.requiresSystemPreferences)
    }

    @Test("Camera is requestable")
    func cameraRequestable() {
        #expect(TestPermissionType.camera.isRequestable)
    }

    @Test("Microphone is requestable")
    func microphoneRequestable() {
        #expect(TestPermissionType.microphone.isRequestable)
    }

    @Test("isRequestable and requiresSystemPreferences are mutually exclusive")
    func mutuallyExclusive() {
        for perm in TestPermissionType.allCases {
            #expect(perm.isRequestable != perm.requiresSystemPreferences,
                    "\(perm) should be either requestable or require sys prefs, not both")
        }
    }
}

@Suite("PermissionStatus")
struct PermissionStatusTests {
    @Test("All 8 statuses exist")
    func allStatuses() {
        #expect(TestPermissionStatus.allCases.count == 8)
    }

    @Test("Only notDetermined can request")
    func onlyNotDeterminedCanRequest() {
        for status in TestPermissionStatus.allCases {
            if status == .notDetermined {
                #expect(status.canRequest)
            } else {
                #expect(!status.canRequest)
            }
        }
    }

    @Test("Granted statuses: authorized, limited, provisional, ephemeral")
    func grantedStatuses() {
        #expect(TestPermissionStatus.authorized.isGranted)
        #expect(TestPermissionStatus.limited.isGranted)
        #expect(TestPermissionStatus.provisional.isGranted)
        #expect(TestPermissionStatus.ephemeral.isGranted)
    }

    @Test("Non-granted statuses")
    func nonGrantedStatuses() {
        #expect(!TestPermissionStatus.notDetermined.isGranted)
        #expect(!TestPermissionStatus.denied.isGranted)
        #expect(!TestPermissionStatus.restricted.isGranted)
        #expect(!TestPermissionStatus.unknown.isGranted)
    }

    @Test("All statuses have icons")
    func allHaveIcons() {
        for status in TestPermissionStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    @Test("Authorized has checkmark icon")
    func authorizedIcon() {
        #expect(TestPermissionStatus.authorized.icon.contains("checkmark"))
    }

    @Test("Denied has xmark icon")
    func deniedIcon() {
        #expect(TestPermissionStatus.denied.icon.contains("xmark"))
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
