import CloudKit
import Combine
import Foundation
import SwiftData

@MainActor
final class CloudSyncManager: ObservableObject {
  static let shared = CloudSyncManager()

  @Published private(set) var isSyncing: Bool = false
  @Published private(set) var lastSyncDate: Date?
  @Published private(set) var syncErrors: [SyncError] = []

  private let container: CKContainer
  private let privateDatabase: CKDatabase
  private var modelContext: ModelContext?

  private init() {
    container = CKContainer(identifier: "iCloud.app.teathe.thea")
    privateDatabase = container.privateCloudDatabase
    loadLastSyncDate()
  }

  // MARK: - Setup

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  // MARK: - Sync Operations

  func performFullSync() async throws {
    guard !isSyncing else { return }
    isSyncing = true
    defer { isSyncing = false }

    syncErrors = []

    do {
      try await checkAccountStatus()
      try await syncConversations()
      try await syncProjects()
      try await syncSettings()

      lastSyncDate = Date()
      saveLastSyncDate()
    } catch {
      let syncError = SyncError(
        timestamp: Date(),
        errorDescription: error.localizedDescription,
        errorType: .unknown
      )
      syncErrors.append(syncError)
      throw error
    }
  }

  func performIncrementalSync() async throws {
    guard !isSyncing else { return }
    isSyncing = true
    defer { isSyncing = false }

    do {
      try await checkAccountStatus()

      let lastSync = lastSyncDate ?? Date.distantPast

      try await syncConversationsSince(lastSync)
      try await syncProjectsSince(lastSync)

      lastSyncDate = Date()
      saveLastSyncDate()
    } catch {
      let syncError = SyncError(
        timestamp: Date(),
        errorDescription: error.localizedDescription,
        errorType: .incrementalSyncFailed
      )
      syncErrors.append(syncError)
      throw error
    }
  }

  // MARK: - Account Status

  private func checkAccountStatus() async throws {
    let status = try await container.accountStatus()

    switch status {
    case .available:
      return
    case .noAccount:
      throw CloudSyncError.noiCloudAccount
    case .restricted:
      throw CloudSyncError.iCloudRestricted
    case .couldNotDetermine:
      throw CloudSyncError.accountStatusUnknown
    case .temporarilyUnavailable:
      throw CloudSyncError.temporarilyUnavailable
    @unknown default:
      throw CloudSyncError.accountStatusUnknown
    }
  }

  // MARK: - Conversations Sync

  private func syncConversations() async throws {
    guard let modelContext = modelContext else { return }

    let descriptor = FetchDescriptor<Conversation>()
    let localConversations = try modelContext.fetch(descriptor)

    for conversation in localConversations {
      try await uploadConversation(conversation)
    }

    try await downloadNewConversations()
  }

  private func syncConversationsSince(_ date: Date) async throws {
    guard let modelContext = modelContext else { return }

    let predicate = #Predicate<Conversation> { conversation in
      conversation.updatedAt > date
    }
    let descriptor = FetchDescriptor<Conversation>(predicate: predicate)
    let updatedConversations = try modelContext.fetch(descriptor)

    for conversation in updatedConversations {
      try await uploadConversation(conversation)
    }

    try await downloadNewConversationsSince(date)
  }

  private func uploadConversation(_ conversation: Conversation) async throws {
    let record = CKRecord(
      recordType: "Conversation", recordID: CKRecord.ID(recordName: conversation.id.uuidString))

    record["title"] = conversation.title
    record["createdAt"] = conversation.createdAt
    record["updatedAt"] = conversation.updatedAt
    record["isPinned"] = conversation.isPinned

    if let projectID = conversation.projectID {
      record["projectID"] = projectID.uuidString
    }

    try await privateDatabase.save(record)

    for message in conversation.messages {
      try await uploadMessage(message, conversationID: conversation.id)
    }
  }

  private func uploadMessage(_ message: Message, conversationID: UUID) async throws {
    let record = CKRecord(
      recordType: "Message", recordID: CKRecord.ID(recordName: message.id.uuidString))

    record["content"] = message.content.textValue
    record["messageRole"] = message.messageRole.rawValue
    record["timestamp"] = message.timestamp
    record["conversationID"] = conversationID.uuidString

    if let model = message.model {
      record["model"] = model
    }

    try await privateDatabase.save(record)
  }

  private func downloadNewConversations() async throws {
    let query = CKQuery(recordType: "Conversation", predicate: NSPredicate(value: true))
    query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

    let results = try await privateDatabase.records(matching: query)

    for (recordID, result) in results.matchResults {
      switch result {
      case .success(let record):
        try await processConversationRecord(record)
      case .failure(let error):
        print("Failed to fetch conversation \(recordID): \(error)")
      }
    }
  }

  private func downloadNewConversationsSince(_ date: Date) async throws {
    let predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
    let query = CKQuery(recordType: "Conversation", predicate: predicate)

    let results = try await privateDatabase.records(matching: query)

    for (recordID, result) in results.matchResults {
      switch result {
      case .success(let record):
        try await processConversationRecord(record)
      case .failure(let error):
        print("Failed to fetch conversation \(recordID): \(error)")
      }
    }
  }

  private func processConversationRecord(_ record: CKRecord) async throws {
    guard let modelContext = modelContext else { return }

    let conversationID = UUID(uuidString: record.recordID.recordName) ?? UUID()
    let title = record["title"] as? String ?? "Untitled"
    let createdAt = record["createdAt"] as? Date ?? Date()
    let updatedAt = record["updatedAt"] as? Date ?? Date()
    let isPinned = record["isPinned"] as? Bool ?? false
    let projectIDString = record["projectID"] as? String
    let projectID = projectIDString != nil ? UUID(uuidString: projectIDString!) : nil

    let descriptor = FetchDescriptor<Conversation>(
      predicate: #Predicate { $0.id == conversationID }
    )
    let existingConversations = try modelContext.fetch(descriptor)

    if let existing = existingConversations.first {
      if updatedAt > existing.updatedAt {
        existing.title = title
        existing.updatedAt = updatedAt
        existing.isPinned = isPinned
        existing.projectID = projectID
      }
    } else {
      let newConversation = Conversation(
        id: conversationID,
        title: title,
        projectID: projectID
      )
      newConversation.createdAt = createdAt
      newConversation.updatedAt = updatedAt
      newConversation.isPinned = isPinned

      modelContext.insert(newConversation)
    }

    try modelContext.save()

    try await downloadMessagesForConversation(conversationID)
  }

  private func downloadMessagesForConversation(_ conversationID: UUID) async throws {
    let predicate = NSPredicate(format: "conversationID == %@", conversationID.uuidString)
    let query = CKQuery(recordType: "Message", predicate: predicate)

    let results = try await privateDatabase.records(matching: query)

    for (recordID, result) in results.matchResults {
      switch result {
      case .success(let record):
        try processMessageRecord(record, conversationID: conversationID)
      case .failure(let error):
        print("Failed to fetch message \(recordID): \(error)")
      }
    }
  }

  private func processMessageRecord(_ record: CKRecord, conversationID: UUID) throws {
    guard let modelContext = modelContext else { return }

    let messageID = UUID(uuidString: record.recordID.recordName) ?? UUID()
    let contentText = record["content"] as? String ?? ""
    let roleString = record["messageRole"] as? String ?? "user"
    let messageRole = MessageRole(rawValue: roleString) ?? .user
    let timestamp = record["timestamp"] as? Date ?? Date()
    let model = record["model"] as? String

    let descriptor = FetchDescriptor<Message>(
      predicate: #Predicate { $0.id == messageID }
    )
    let existingMessages = try modelContext.fetch(descriptor)

    if existingMessages.isEmpty {
      let newMessage = Message(
        id: messageID,
        conversationID: conversationID,
        role: messageRole,
        content: .text(contentText),
        timestamp: timestamp,
        model: model
      )

      modelContext.insert(newMessage)
      try modelContext.save()
    }
  }

  // MARK: - Projects Sync

  private func syncProjects() async throws {
    guard let modelContext = modelContext else { return }

    let descriptor = FetchDescriptor<Project>()
    let localProjects = try modelContext.fetch(descriptor)

    for project in localProjects {
      try await uploadProject(project)
    }

    try await downloadNewProjects()
  }

  private func syncProjectsSince(_ date: Date) async throws {
    guard let modelContext = modelContext else { return }

    let predicate = #Predicate<Project> { project in
      project.updatedAt > date
    }
    let descriptor = FetchDescriptor<Project>(predicate: predicate)
    let updatedProjects = try modelContext.fetch(descriptor)

    for project in updatedProjects {
      try await uploadProject(project)
    }

    try await downloadNewProjectsSince(date)
  }

  private func uploadProject(_ project: Project) async throws {
    let record = CKRecord(
      recordType: "Project", recordID: CKRecord.ID(recordName: project.id.uuidString))

    record["title"] = project.title
    record["customInstructions"] = project.customInstructions
    record["createdAt"] = project.createdAt
    record["updatedAt"] = project.updatedAt

    try await privateDatabase.save(record)
  }

  private func downloadNewProjects() async throws {
    let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))

    let results = try await privateDatabase.records(matching: query)

    for (recordID, result) in results.matchResults {
      switch result {
      case .success(let record):
        try processProjectRecord(record)
      case .failure(let error):
        print("Failed to fetch project \(recordID): \(error)")
      }
    }
  }

  private func downloadNewProjectsSince(_ date: Date) async throws {
    let predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
    let query = CKQuery(recordType: "Project", predicate: predicate)

    let results = try await privateDatabase.records(matching: query)

    for (recordID, result) in results.matchResults {
      switch result {
      case .success(let record):
        try processProjectRecord(record)
      case .failure(let error):
        print("Failed to fetch project \(recordID): \(error)")
      }
    }
  }

  private func processProjectRecord(_ record: CKRecord) throws {
    guard let modelContext = modelContext else { return }

    let projectID = UUID(uuidString: record.recordID.recordName) ?? UUID()
    let title = record["title"] as? String ?? "Untitled"
    let customInstructions = record["customInstructions"] as? String ?? ""
    let createdAt = record["createdAt"] as? Date ?? Date()
    let updatedAt = record["updatedAt"] as? Date ?? Date()

    let descriptor = FetchDescriptor<Project>(
      predicate: #Predicate { $0.id == projectID }
    )
    let existingProjects = try modelContext.fetch(descriptor)

    if let existing = existingProjects.first {
      if updatedAt > existing.updatedAt {
        existing.title = title
        existing.customInstructions = customInstructions
        existing.updatedAt = updatedAt
      }
    } else {
      let newProject = Project(id: projectID, title: title, customInstructions: customInstructions)
      newProject.createdAt = createdAt
      newProject.updatedAt = updatedAt

      modelContext.insert(newProject)
    }

    try modelContext.save()
  }

  // MARK: - Settings Sync

  private func syncSettings() async throws {
    let record = CKRecord(recordType: "Settings", recordID: CKRecord.ID(recordName: "userSettings"))

    let settings = SettingsManager.shared

    record["defaultProvider"] = settings.defaultProvider
    record["theme"] = settings.theme
    record["fontSize"] = settings.fontSize
    record["streamResponses"] = settings.streamResponses
    record["analyticsEnabled"] = settings.analyticsEnabled

    try await privateDatabase.save(record)
  }

  // MARK: - Persistence

  private func loadLastSyncDate() {
    if let date = UserDefaults.standard.object(forKey: "lastCloudSyncDate") as? Date {
      lastSyncDate = date
    }
  }

  private func saveLastSyncDate() {
    if let date = lastSyncDate {
      UserDefaults.standard.set(date, forKey: "lastCloudSyncDate")
    }
  }
}

// MARK: - Error Types

enum CloudSyncError: LocalizedError {
  case noiCloudAccount
  case iCloudRestricted
  case accountStatusUnknown
  case temporarilyUnavailable
  case syncFailed
  case uploadFailed
  case downloadFailed

  var errorDescription: String? {
    switch self {
    case .noiCloudAccount:
      return "No iCloud account is configured on this device"
    case .iCloudRestricted:
      return "iCloud access is restricted"
    case .accountStatusUnknown:
      return "Could not determine iCloud account status"
    case .temporarilyUnavailable:
      return "iCloud is temporarily unavailable"
    case .syncFailed:
      return "Sync operation failed"
    case .uploadFailed:
      return "Failed to upload data to iCloud"
    case .downloadFailed:
      return "Failed to download data from iCloud"
    }
  }
}

struct SyncError: Identifiable, Codable {
  let id: UUID
  let timestamp: Date
  let errorDescription: String
  let errorType: SyncErrorType

  init(timestamp: Date, errorDescription: String, errorType: SyncErrorType) {
    self.id = UUID()
    self.timestamp = timestamp
    self.errorDescription = errorDescription
    self.errorType = errorType
  }

  enum SyncErrorType: String, Codable {
    case accountIssue
    case networkIssue
    case dataConflict
    case uploadFailed
    case downloadFailed
    case incrementalSyncFailed
    case unknown
  }

  enum CodingKeys: String, CodingKey {
    case id, timestamp, errorDescription, errorType
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    errorDescription = try container.decode(String.self, forKey: .errorDescription)
    errorType = try container.decode(SyncErrorType.self, forKey: .errorType)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(errorDescription, forKey: .errorDescription)
    try container.encode(errorType, forKey: .errorType)
  }
}
