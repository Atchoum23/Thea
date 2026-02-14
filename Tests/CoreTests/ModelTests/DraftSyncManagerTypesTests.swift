// DraftSyncManagerTypesTests.swift
// Tests for DraftSyncManager types, merge logic, and draft lifecycle
// Standalone test doubles — no dependency on actual DraftSyncManager

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirrors DraftAttachment.AttachmentType
private enum TestAttachmentType: String, CaseIterable, Sendable, Codable {
    case image
    case file
    case audio
    case video
    case code
}

/// Mirrors DraftAttachment
private struct TestDraftAttachment: Identifiable, Sendable, Codable {
    let id: UUID
    let type: TestAttachmentType
    let localPath: String?
    let cloudPath: String?
    let fileName: String
    let fileSize: Int64
    let mimeType: String?

    init(
        id: UUID = UUID(),
        type: TestAttachmentType,
        localPath: String? = nil,
        cloudPath: String? = nil,
        fileName: String,
        fileSize: Int64,
        mimeType: String? = nil
    ) {
        self.id = id
        self.type = type
        self.localPath = localPath
        self.cloudPath = cloudPath
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

/// Mirrors InputDraft
private struct TestInputDraft: Identifiable, Sendable, Codable {
    let id: UUID
    var conversationId: UUID?
    var text: String
    var attachments: [TestDraftAttachment]
    var cursorPosition: Int?
    var lastModified: Date
    var deviceId: String

    init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        text: String = "",
        attachments: [TestDraftAttachment] = [],
        cursorPosition: Int? = nil,
        lastModified: Date = Date(),
        deviceId: String = ""
    ) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.attachments = attachments
        self.cursorPosition = cursorPosition
        self.lastModified = lastModified
        self.deviceId = deviceId
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
    }
}

/// Mirrors DraftSyncManager's merge logic
private func mergeDraft(
    local: TestInputDraft?,
    cloud: TestInputDraft,
    currentDeviceId: String
) -> TestInputDraft {
    if let localDraft = local {
        if cloud.lastModified > localDraft.lastModified,
           cloud.deviceId != currentDeviceId {
            return cloud
        }
        return localDraft
    }
    return cloud
}

/// Mirrors DraftSyncManager defaults
private struct DraftSyncDefaults {
    static let syncDelaySeconds: TimeInterval = 120.0
    static let crossDeviceSyncEnabled = true
    static let liveSyncEnabled = false
    static let localStorageKey = "thea.drafts.local"
    static let cloudStorageKey = "thea.drafts.cloud"
}

// MARK: - Tests

@Suite("AttachmentType Cases")
struct AttachmentTypeCaseTests {
    @Test("All 5 attachment types exist")
    func allCases() {
        #expect(TestAttachmentType.allCases.count == 5)
    }

    @Test("Raw values are lowercase")
    func rawValuesLowercase() {
        for type in TestAttachmentType.allCases {
            #expect(type.rawValue == type.rawValue.lowercased())
        }
    }

    @Test("Raw values are unique")
    func rawValuesUnique() {
        let rawValues = TestAttachmentType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for type in TestAttachmentType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TestAttachmentType.self, from: data)
            #expect(decoded == type)
        }
    }
}

@Suite("DraftAttachment")
struct DraftAttachmentTests {
    @Test("Creation with minimal fields")
    func minimalCreation() {
        let a = TestDraftAttachment(type: .image, fileName: "photo.jpg", fileSize: 1024)
        #expect(a.type == .image)
        #expect(a.fileName == "photo.jpg")
        #expect(a.fileSize == 1024)
        #expect(a.localPath == nil)
        #expect(a.cloudPath == nil)
        #expect(a.mimeType == nil)
    }

    @Test("Creation with all fields")
    func fullCreation() {
        let id = UUID()
        let a = TestDraftAttachment(
            id: id,
            type: .file,
            localPath: "/tmp/doc.pdf",
            cloudPath: "icloud/doc.pdf",
            fileName: "doc.pdf",
            fileSize: 1_048_576,
            mimeType: "application/pdf"
        )
        #expect(a.id == id)
        #expect(a.type == .file)
        #expect(a.localPath == "/tmp/doc.pdf")
        #expect(a.cloudPath == "icloud/doc.pdf")
        #expect(a.fileName == "doc.pdf")
        #expect(a.fileSize == 1_048_576)
        #expect(a.mimeType == "application/pdf")
    }

    @Test("Zero file size allowed")
    func zeroFileSize() {
        let a = TestDraftAttachment(type: .code, fileName: "empty.swift", fileSize: 0)
        #expect(a.fileSize == 0)
    }

    @Test("Large file size")
    func largeFileSize() {
        let a = TestDraftAttachment(type: .video, fileName: "movie.mp4", fileSize: 5_368_709_120)
        #expect(a.fileSize == 5_368_709_120) // 5 GB
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let a1 = TestDraftAttachment(type: .image, fileName: "a.jpg", fileSize: 100)
        let a2 = TestDraftAttachment(type: .image, fileName: "a.jpg", fileSize: 100)
        #expect(a1.id != a2.id)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let original = TestDraftAttachment(
            type: .audio,
            localPath: "/tmp/voice.m4a",
            fileName: "voice.m4a",
            fileSize: 2048,
            mimeType: "audio/mp4"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestDraftAttachment.self, from: data)
        #expect(decoded.type == original.type)
        #expect(decoded.fileName == original.fileName)
        #expect(decoded.fileSize == original.fileSize)
        #expect(decoded.mimeType == original.mimeType)
    }
}

@Suite("InputDraft isEmpty")
struct InputDraftIsEmptyTests {
    @Test("Empty text and no attachments is empty")
    func emptyTextNoAttachments() {
        let draft = TestInputDraft()
        #expect(draft.isEmpty)
    }

    @Test("Whitespace-only text is empty")
    func whitespaceOnly() {
        let draft = TestInputDraft(text: "   \n\t  ")
        #expect(draft.isEmpty)
    }

    @Test("Non-empty text is not empty")
    func nonEmptyText() {
        let draft = TestInputDraft(text: "Hello")
        #expect(!draft.isEmpty)
    }

    @Test("Empty text with attachment is not empty")
    func emptyTextWithAttachment() {
        let attachment = TestDraftAttachment(type: .image, fileName: "photo.jpg", fileSize: 1024)
        let draft = TestInputDraft(attachments: [attachment])
        #expect(!draft.isEmpty)
    }

    @Test("Whitespace text with attachment is not empty")
    func whitespaceWithAttachment() {
        let attachment = TestDraftAttachment(type: .file, fileName: "doc.txt", fileSize: 100)
        let draft = TestInputDraft(text: "   ", attachments: [attachment])
        #expect(!draft.isEmpty)
    }

    @Test("Non-empty text with attachment is not empty")
    func textAndAttachment() {
        let attachment = TestDraftAttachment(type: .code, fileName: "main.swift", fileSize: 500)
        let draft = TestInputDraft(text: "Check this code", attachments: [attachment])
        #expect(!draft.isEmpty)
    }

    @Test("Newline-only text is empty")
    func newlineOnly() {
        let draft = TestInputDraft(text: "\n\n\n")
        #expect(draft.isEmpty)
    }

    @Test("Tab-only text is empty")
    func tabOnly() {
        let draft = TestInputDraft(text: "\t\t")
        #expect(draft.isEmpty)
    }

    @Test("Single character is not empty")
    func singleChar() {
        let draft = TestInputDraft(text: "a")
        #expect(!draft.isEmpty)
    }
}

@Suite("InputDraft Creation")
struct InputDraftCreationTests {
    @Test("Default creation")
    func defaultCreation() {
        let draft = TestInputDraft()
        #expect(draft.text.isEmpty)
        #expect(draft.attachments.isEmpty)
        #expect(draft.conversationId == nil)
        #expect(draft.cursorPosition == nil)
        #expect(draft.deviceId.isEmpty)
    }

    @Test("Full creation")
    func fullCreation() {
        let id = UUID()
        let convId = UUID()
        let date = Date(timeIntervalSince1970: 1000)
        let draft = TestInputDraft(
            id: id,
            conversationId: convId,
            text: "Hello world",
            cursorPosition: 5,
            lastModified: date,
            deviceId: "msm3u"
        )
        #expect(draft.id == id)
        #expect(draft.conversationId == convId)
        #expect(draft.text == "Hello world")
        #expect(draft.cursorPosition == 5)
        #expect(draft.lastModified == date)
        #expect(draft.deviceId == "msm3u")
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let d1 = TestInputDraft(text: "same")
        let d2 = TestInputDraft(text: "same")
        #expect(d1.id != d2.id)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let original = TestInputDraft(
            conversationId: UUID(),
            text: "Test message",
            cursorPosition: 12,
            deviceId: "mbam2"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestInputDraft.self, from: data)
        #expect(decoded.text == original.text)
        #expect(decoded.conversationId == original.conversationId)
        #expect(decoded.cursorPosition == original.cursorPosition)
        #expect(decoded.deviceId == original.deviceId)
    }

    @Test("Mutable text")
    func mutableText() {
        var draft = TestInputDraft(text: "initial")
        draft.text = "modified"
        #expect(draft.text == "modified")
    }

    @Test("Mutable attachments")
    func mutableAttachments() {
        var draft = TestInputDraft()
        #expect(draft.attachments.isEmpty)
        draft.attachments.append(TestDraftAttachment(type: .image, fileName: "a.jpg", fileSize: 100))
        #expect(draft.attachments.count == 1)
    }
}

@Suite("Draft Merge Logic")
struct DraftMergeTests {
    let deviceA = "msm3u"
    let deviceB = "mbam2"

    @Test("No local draft — use cloud")
    func noLocalUsesCloud() {
        let cloud = TestInputDraft(text: "from cloud", deviceId: deviceB)
        let result = mergeDraft(local: nil, cloud: cloud, currentDeviceId: deviceA)
        #expect(result.text == "from cloud")
    }

    @Test("Cloud newer from different device — use cloud")
    func cloudNewerDifferentDevice() {
        let local = TestInputDraft(
            text: "local old",
            lastModified: Date(timeIntervalSince1970: 1000),
            deviceId: deviceA
        )
        let cloud = TestInputDraft(
            text: "cloud new",
            lastModified: Date(timeIntervalSince1970: 2000),
            deviceId: deviceB
        )
        let result = mergeDraft(local: local, cloud: cloud, currentDeviceId: deviceA)
        #expect(result.text == "cloud new")
    }

    @Test("Cloud newer from same device — keep local")
    func cloudNewerSameDevice() {
        let local = TestInputDraft(
            text: "local",
            lastModified: Date(timeIntervalSince1970: 1000),
            deviceId: deviceA
        )
        let cloud = TestInputDraft(
            text: "cloud",
            lastModified: Date(timeIntervalSince1970: 2000),
            deviceId: deviceA
        )
        let result = mergeDraft(local: local, cloud: cloud, currentDeviceId: deviceA)
        #expect(result.text == "local")
    }

    @Test("Local newer — keep local")
    func localNewer() {
        let local = TestInputDraft(
            text: "local new",
            lastModified: Date(timeIntervalSince1970: 2000),
            deviceId: deviceA
        )
        let cloud = TestInputDraft(
            text: "cloud old",
            lastModified: Date(timeIntervalSince1970: 1000),
            deviceId: deviceB
        )
        let result = mergeDraft(local: local, cloud: cloud, currentDeviceId: deviceA)
        #expect(result.text == "local new")
    }

    @Test("Same timestamp — keep local (bias toward current device)")
    func sameTimestampKeepsLocal() {
        let timestamp = Date(timeIntervalSince1970: 1500)
        let local = TestInputDraft(text: "local", lastModified: timestamp, deviceId: deviceA)
        let cloud = TestInputDraft(text: "cloud", lastModified: timestamp, deviceId: deviceB)
        let result = mergeDraft(local: local, cloud: cloud, currentDeviceId: deviceA)
        #expect(result.text == "local")
    }

    @Test("Both from same device, cloud newer — still keep local")
    func sameDeviceCloudNewer() {
        let local = TestInputDraft(
            text: "local",
            lastModified: Date(timeIntervalSince1970: 1000),
            deviceId: deviceA
        )
        let cloud = TestInputDraft(
            text: "cloud",
            lastModified: Date(timeIntervalSince1970: 2000),
            deviceId: deviceA
        )
        let result = mergeDraft(local: local, cloud: cloud, currentDeviceId: deviceA)
        #expect(result.text == "local")
    }
}

@Suite("DraftSync Defaults")
struct DraftSyncDefaultsTests {
    @Test("Default sync delay is 2 minutes")
    func syncDelay() {
        #expect(DraftSyncDefaults.syncDelaySeconds == 120.0)
    }

    @Test("Cross-device sync enabled by default")
    func crossDeviceSync() {
        #expect(DraftSyncDefaults.crossDeviceSyncEnabled)
    }

    @Test("Live sync disabled by default")
    func liveSyncDisabled() {
        #expect(!DraftSyncDefaults.liveSyncEnabled)
    }

    @Test("Storage keys are prefixed with thea.drafts")
    func storageKeys() {
        #expect(DraftSyncDefaults.localStorageKey.hasPrefix("thea.drafts."))
        #expect(DraftSyncDefaults.cloudStorageKey.hasPrefix("thea.drafts."))
    }

    @Test("Local and cloud storage keys are different")
    func storageKeysDifferent() {
        #expect(DraftSyncDefaults.localStorageKey != DraftSyncDefaults.cloudStorageKey)
    }
}

@Suite("Draft Lifecycle")
struct DraftLifecycleTests {
    @Test("Draft starts empty, becomes non-empty with text")
    func lifecycleEmptyToText() {
        var draft = TestInputDraft()
        #expect(draft.isEmpty)
        draft.text = "Hello"
        #expect(!draft.isEmpty)
    }

    @Test("Draft becomes empty when text cleared")
    func lifecycleTextToEmpty() {
        var draft = TestInputDraft(text: "Hello")
        #expect(!draft.isEmpty)
        draft.text = ""
        #expect(draft.isEmpty)
    }

    @Test("Draft with only attachments is not empty")
    func attachmentOnlyNotEmpty() {
        var draft = TestInputDraft()
        draft.attachments.append(TestDraftAttachment(type: .file, fileName: "a.txt", fileSize: 10))
        #expect(!draft.isEmpty)
    }

    @Test("Draft cursor position tracks editing")
    func cursorTracking() {
        var draft = TestInputDraft(text: "Hello World", cursorPosition: 5)
        #expect(draft.cursorPosition == 5)
        draft.text = "Hello Beautiful World"
        draft.cursorPosition = 15
        #expect(draft.cursorPosition == 15)
    }

    @Test("Multiple attachments")
    func multipleAttachments() {
        var draft = TestInputDraft()
        draft.attachments.append(TestDraftAttachment(type: .image, fileName: "a.jpg", fileSize: 100))
        draft.attachments.append(TestDraftAttachment(type: .code, fileName: "b.swift", fileSize: 200))
        draft.attachments.append(TestDraftAttachment(type: .audio, fileName: "c.m4a", fileSize: 300))
        #expect(draft.attachments.count == 3)
        #expect(!draft.isEmpty)
    }
}
