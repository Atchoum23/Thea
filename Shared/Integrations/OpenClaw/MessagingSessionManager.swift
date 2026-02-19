import Foundation
import SwiftData
import OSLog
import Security

// MARK: - Messaging Session Manager
// Per-platform-per-peer session management with SwiftData persistence.
// Implements MMR (Maximal Marginal Relevance) re-ranking from OpenClaw research:
//   score = λ * relevance(q, m) - (1-λ) * max(similarity(m, s)) for s in selected
// Session key format: "{platform.rawValue}:{chatId}:{senderId}"

@MainActor
final class MessagingSessionManager: ObservableObject {
    static let shared = MessagingSessionManager()

    @Published private(set) var activeSessions: [MessagingSession] = []

    private let logger = Logger(subsystem: "ai.thea.app", category: "MessagingSessionManager")
    private var modelContext: ModelContext?

    private init() {
        setupModelContext()
    }

    private func setupModelContext() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: MessagingSession.self, configurations: config)
            modelContext = container.mainContext
            loadActiveSessions()
        } catch {
            logger.error("Failed to set up MessagingSession SwiftData context: \(error)")
        }
    }

    private func loadActiveSessions() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<MessagingSession>(
            sortBy: [SortDescriptor(\.lastActivity, order: .reverse)]
        )
        activeSessions = (try? ctx.fetch(descriptor)) ?? []
    }

    // MARK: - Message Handling

    /// Persist inbound message to the appropriate session.
    func appendMessage(_ message: TheaGatewayMessage) async {
        let key = sessionKey(for: message)

        if let existing = activeSessions.first(where: { $0.key == key }) {
            existing.lastActivity = message.timestamp
            existing.appendMessage(message)
        } else {
            let session = MessagingSession(
                key: key,
                platform: message.platform.rawValue,
                chatId: message.chatId,
                senderId: message.senderId,
                senderName: message.senderName
            )
            session.appendMessage(message)
            modelContext?.insert(session)
            activeSessions.insert(session, at: 0)
        }

        try? modelContext?.save()
    }

    /// Append an outbound (AI) response to a session.
    func appendOutbound(text: String, toSessionKey key: String) {
        guard let session = activeSessions.first(where: { $0.key == key }) else { return }
        let entry = SessionMessageEntry(role: "assistant", content: text, timestamp: Date())
        session.appendEntry(entry)
        session.lastActivity = Date()
        try? modelContext?.save()
    }

    // MARK: - Session Operations

    func session(for message: TheaGatewayMessage) -> MessagingSession? {
        activeSessions.first(where: { $0.key == sessionKey(for: message) })
    }

    func resetSession(key: String) {
        guard let session = activeSessions.first(where: { $0.key == key }) else { return }
        session.clearHistory()
        // periphery:ignore - Reserved: session(for:) instance method reserved for future feature activation
        try? modelContext?.save()
    }

    // periphery:ignore - Reserved: resetSession(key:) instance method reserved for future feature activation
    func resetAll() {
        for session in activeSessions { session.clearHistory() }
        try? modelContext?.save()
        logger.info("All messaging sessions reset")
    }

    func deleteSession(key: String) {
        guard let session = activeSessions.first(where: { $0.key == key }),
              let ctx = modelContext else { return }
        ctx.delete(session)
        activeSessions.removeAll(where: { $0.key == key })
        // periphery:ignore - Reserved: deleteSession(key:) instance method reserved for future feature activation
        try? ctx.save()
    }

    // MARK: - MMR Memory Re-ranking
    // Implements Maximal Marginal Relevance for context retrieval.
    // Balances relevance to query vs. diversity among selected messages.

    /// Returns the most relevant + diverse context messages for AI prompting.
    func relevantContext(for query: String, sessionKey: String, maxItems: Int = 10) -> [String] {
        guard let session = activeSessions.first(where: { $0.key == sessionKey }) else { return [] }
        let history = session.decodedHistory()
        guard !history.isEmpty else { return [] }

// periphery:ignore - Reserved: relevantContext(for:sessionKey:maxItems:) instance method reserved for future feature activation

        let lambda: Double = 0.6  // balance: 1.0 = pure relevance, 0.0 = pure diversity
        let queryTokens = Set(query.lowercased().split(separator: " ").map(String.init))

        // BM25-style relevance scoring
        func relevance(_ entry: SessionMessageEntry) -> Double {
            let tokens = Set(entry.content.lowercased().split(separator: " ").map(String.init))
            let intersection = queryTokens.intersection(tokens)
            guard !tokens.isEmpty else { return 0 }
            return Double(intersection.count) / Double(tokens.count)
        }

        // Cosine-like similarity between two strings (token overlap)
        func similarity(_ a: SessionMessageEntry, _ b: SessionMessageEntry) -> Double {
            let tokA = Set(a.content.lowercased().split(separator: " ").map(String.init))
            let tokB = Set(b.content.lowercased().split(separator: " ").map(String.init))
            let union = tokA.union(tokB)
            guard !union.isEmpty else { return 0 }
            return Double(tokA.intersection(tokB).count) / Double(union.count)
        }

        var selected: [SessionMessageEntry] = []
        var candidates = history

        // Temporal decay: reduce relevance of very old messages
        let now = Date()
        func temporalWeight(_ entry: SessionMessageEntry) -> Double {
            let age = now.timeIntervalSince(entry.timestamp)
            return max(0.1, 1.0 - (age / (7 * 24 * 3600)))  // decay over 7 days
        }

        while selected.count < maxItems, !candidates.isEmpty {
            let scored = candidates.map { entry -> (SessionMessageEntry, Double) in
                let rel = relevance(entry) * temporalWeight(entry)
                let maxSim = selected.isEmpty ? 0.0 : selected.map { similarity(entry, $0) }.max() ?? 0.0
                let score = lambda * rel - (1 - lambda) * maxSim
                return (entry, score)
            }
            guard let best = scored.max(by: { $0.1 < $1.1 }) else { break }
            selected.append(best.0)
            candidates.removeAll(where: { $0.id == best.0.id })
        }

        return selected.sorted(by: { $0.timestamp < $1.timestamp })
                       .map { "[\($0.role)] \($0.content)" }
    }

    // MARK: - Daily Reset

    func scheduleDailyReset() {
        // Reset all sessions at 04:00 daily via background task
        Task {
            // periphery:ignore - Reserved: scheduleDailyReset() instance method reserved for future feature activation
            while true {
                let calendar = Calendar.current
                let now = Date()
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = 4; components.minute = 0; components.second = 0
                guard let next4am = calendar.date(from: components) else { break }
                let target = next4am > now ? next4am : Calendar.current.date(byAdding: .day, value: 1, to: next4am) ?? next4am
                let interval = target.timeIntervalSince(now)
                try? await Task.sleep(for: .seconds(interval))
                await MainActor.run { self.resetAll() }
                self.logger.info("Daily session reset at 04:00")
            }
        }
    }

    // MARK: - Private

    private func sessionKey(for message: TheaGatewayMessage) -> String {
        "\(message.platform.rawValue):\(message.chatId):\(message.senderId)"
    }
}

// MARK: - SwiftData Model

@Model
final class MessagingSession {
    var key: String
    var platform: String
    var chatId: String
    var senderId: String
    var senderName: String
    var lastActivity: Date
    var agentId: String
    /// JSON-encoded [SessionMessageEntry] array
    var historyData: Data

    init(key: String, platform: String, chatId: String, senderId: String, senderName: String) {
        self.key = key
        self.platform = platform
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.lastActivity = Date()
        self.agentId = "main"
        self.historyData = Data()
    }

    func appendMessage(_ message: TheaGatewayMessage) {
        let entry = SessionMessageEntry(role: "user", content: message.content, timestamp: message.timestamp)
        appendEntry(entry)
    }

    func appendEntry(_ entry: SessionMessageEntry) {
        var history = decodedHistory()
        history.append(entry)
        // Keep last 200 messages to avoid unbounded growth
        if history.count > 200 { history = Array(history.dropFirst(history.count - 200)) }
        historyData = (try? JSONEncoder().encode(history)) ?? Data()
    }

    func decodedHistory() -> [SessionMessageEntry] {
        (try? JSONDecoder().decode([SessionMessageEntry].self, from: historyData)) ?? []
    }

    func clearHistory() {
        historyData = Data()
    }
}

// MARK: - Session Message Entry

struct SessionMessageEntry: Codable, Identifiable, Sendable {
    let id: String
    let role: String       // "user" | "assistant"
    let content: String
    let timestamp: Date

    init(role: String, content: String, timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Credentials Store (Keychain)

struct MessagingCredentialsStore {
    private static let service = "ai.thea.messaging"

    static func load(for platform: MessagingPlatform) -> MessagingCredentials {
        let key = "\(service).\(platform.rawValue)"
        guard let data = keychainRead(key: key),
              let creds = try? JSONDecoder().decode(MessagingCredentials.self, from: data)
        else { return MessagingCredentials() }
        return creds
    }

    static func save(_ creds: MessagingCredentials, for platform: MessagingPlatform) {
        let key = "\(service).\(platform.rawValue)"
        guard let data = try? JSONEncoder().encode(creds) else { return }
        keychainWrite(key: key, data: data)
    }

    static func delete(for platform: MessagingPlatform) {
        let key = "\(service).\(platform.rawValue)"
        // periphery:ignore - Reserved: delete(for:) static method reserved for future feature activation
        keychainDelete(key: key)
    }

    // MARK: Private Keychain Helpers

    @discardableResult
    private static func keychainWrite(key: String, data: Data) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func keychainRead(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func keychainDelete(key: String) {
        // periphery:ignore - Reserved: keychainDelete(key:) static method reserved for future feature activation
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - PersonalKnowledgeGraph Extension

extension PersonalKnowledgeGraph {
    /// Returns frequently-referenced entities for messaging context injection.
    // periphery:ignore - Reserved: contextForMessaging() instance method reserved for future feature activation
    func contextForMessaging() -> [String] {
        recentEntities(limit: 20)
            .filter { $0.referenceCount > 2 }
            .map { entity in
                let attrs = entity.attributes.isEmpty
                    ? ""
                    : " (\(entity.attributes.values.prefix(3).joined(separator: ", ")))"
                return "[\(entity.type.rawValue)] \(entity.name)\(attrs)"
            }
    }
}
