import Testing
import Foundation

// MARK: - Test Doubles (mirror production types)

/// Mirrors NotificationUrgency from NotificationIntelligenceService.swift
private enum TestNotifUrgency: String, Codable, Sendable, CaseIterable, Comparable {
    case critical
    case high
    case medium
    case low

    static func < (lhs: TestNotifUrgency, rhs: TestNotifUrgency) -> Bool {
        let order: [TestNotifUrgency] = [.low, .medium, .high, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "bell.fill"
        case .low: return "bell"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

/// Mirrors IntelNotifCategory from NotificationIntelligenceService.swift
private enum TestNotifCategory: String, Codable, Sendable, CaseIterable {
    case messaging
    case calendar
    case email
    case finance
    case health
    case delivery
    case social
    case news
    case system
    case other

    var icon: String {
        switch self {
        case .messaging: return "message.fill"
        case .calendar: return "calendar"
        case .email: return "envelope.fill"
        case .finance: return "creditcard.fill"
        case .health: return "heart.fill"
        case .delivery: return "shippingbox.fill"
        case .social: return "person.2.fill"
        case .news: return "newspaper.fill"
        case .system: return "gear"
        case .other: return "bell.fill"
        }
    }

    var displayName: String {
        switch self {
        case .other: return "Other"
        default: return rawValue.capitalized
        }
    }
}

/// Mirrors IntelNotifActionType from NotificationIntelligenceService.swift
private enum TestNotifActionType: String, Codable, Sendable {
    case draftReply
    case summarize
    case prepareBriefing
    case trackPackage
    case logTransaction
    case logHealthData
    case clearNotification
    case createTask
    case setReminder
}

/// Mirrors AppNotificationSettings from NotificationIntelligenceService.swift
private struct TestAppNotifSettings: Codable, Sendable {
    var enabled: Bool
    var autoActionsEnabled: Bool
    var urgencyOverride: TestNotifUrgency?
    var mutedUntil: Date?

    init(
        enabled: Bool = true,
        autoActionsEnabled: Bool = false,
        urgencyOverride: TestNotifUrgency? = nil,
        mutedUntil: Date? = nil
    ) {
        self.enabled = enabled
        self.autoActionsEnabled = autoActionsEnabled
        self.urgencyOverride = urgencyOverride
        self.mutedUntil = mutedUntil
    }
}

/// Mirrors NotificationClearance from NotificationIntelligenceService.swift
private struct TestNotifClearance: Identifiable, Codable, Sendable {
    var id: UUID { notificationID }
    let notificationID: UUID
    let appIdentifier: String
    let clearedAt: Date
    let clearedBy: String
    let deviceID: String
}

/// Mirrors NotificationIntelligenceStats from NotificationIntelligenceService.swift
private struct TestNotifStats: Sendable {
    let totalClassified: Int
    let byUrgency: [TestNotifUrgency: Int]
    let byCategory: [TestNotifCategory: Int]
    let totalCleared: Int
    let totalActioned: Int
    let autoActionRate: Double
}

/// Simple notification record for testing
private struct TestNotifRecord: Identifiable {
    let id = UUID()
    let appIdentifier: String
    let title: String?
    let body: String?
    let category: String?
    let timestamp: Date

    init(
        appIdentifier: String,
        title: String? = nil,
        body: String? = nil,
        category: String? = nil,
        timestamp: Date = Date()
    ) {
        self.appIdentifier = appIdentifier
        self.title = title
        self.body = body
        self.category = category
        self.timestamp = timestamp
    }
}

// MARK: - Classification Logic (mirrors NotificationIntelligenceService)

private struct TestNotifClassifier {

    static func determineUrgency(_ record: TestNotifRecord, appSettings: TestAppNotifSettings? = nil) -> TestNotifUrgency {
        let title = (record.title ?? "").lowercased()
        let body = (record.body ?? "").lowercased()
        let combined = title + " " + body

        let criticalKeywords = ["emergency", "urgent", "critical", "alert", "security",
                                 "breach", "immediate", "warning", "danger", "failed payment"]
        if criticalKeywords.contains(where: { combined.contains($0) }) {
            return .critical
        }

        let highKeywords = ["important", "action required", "deadline", "overdue",
                            "reminder", "missed call", "voicemail", "payment due",
                            "expiring", "cancellation"]
        if highKeywords.contains(where: { combined.contains($0) }) {
            return .high
        }

        let mediumKeywords = ["message from", "new message", "reply", "mentioned you",
                               "invitation", "meeting", "appointment", "update available",
                               "delivery", "shipped"]
        if mediumKeywords.contains(where: { combined.contains($0) }) {
            return .medium
        }

        if let override = appSettings?.urgencyOverride {
            return override
        }

        return .low
    }

    static func determineCategory(_ record: TestNotifRecord) -> TestNotifCategory {
        let appId = record.appIdentifier.lowercased()
        let combined = ((record.title ?? "") + " " + (record.body ?? "")).lowercased()

        let messagingApps = ["whatsapp", "telegram", "signal", "messages", "slack",
                              "discord", "imessage", "viber"]
        if messagingApps.contains(where: { appId.contains($0) }) {
            return .messaging
        }

        if appId.contains("calendar") || combined.contains("meeting") ||
           combined.contains("appointment") || combined.contains("event") {
            return .calendar
        }

        if appId.contains("mail") || appId.contains("gmail") || appId.contains("outlook") {
            return .email
        }

        let financeKeywords = ["payment", "transaction", "balance", "invoice", "transfer",
                                "bank", "credit", "debit"]
        if financeKeywords.contains(where: { combined.contains($0) }) ||
           appId.contains("bank") || appId.contains("finance") || appId.contains("revolut") ||
           appId.contains("paypal") {
            return .finance
        }

        if appId.contains("health") || combined.contains("heart rate") ||
           combined.contains("workout") || combined.contains("medication") {
            return .health
        }

        if combined.contains("delivered") || combined.contains("shipped") ||
           combined.contains("tracking") || combined.contains("package") {
            return .delivery
        }

        let socialApps = ["instagram", "facebook", "twitter", "tiktok", "linkedin",
                           "reddit", "mastodon", "threads"]
        if socialApps.contains(where: { appId.contains($0) }) {
            return .social
        }

        if appId.contains("news") || combined.contains("breaking") {
            return .news
        }

        if appId.contains("com.apple") {
            return .system
        }

        return .other
    }

    static func determineSuggestedActions(
        urgency: TestNotifUrgency,
        category: TestNotifCategory
    ) -> [TestNotifActionType] {
        var actions: [TestNotifActionType] = []

        switch category {
        case .messaging:
            actions.append(.draftReply)
        case .calendar:
            actions.append(.prepareBriefing)
        case .email:
            actions.append(.summarize)
            if urgency == .high || urgency == .critical {
                actions.append(.draftReply)
            }
        case .delivery:
            actions.append(.trackPackage)
        case .finance:
            actions.append(.logTransaction)
        case .health:
            actions.append(.logHealthData)
        default:
            break
        }

        actions.append(.clearNotification)
        return actions
    }

    static func shouldAutoAction(
        actionConfidence: Double,
        requiresApproval: Bool,
        threshold: Double,
        autoActionEnabled: Bool,
        appAutoEnabled: Bool
    ) -> Bool {
        guard appAutoEnabled || autoActionEnabled else { return false }
        return actionConfidence >= threshold && !requiresApproval
    }
}

// MARK: - Tests

@Suite("G2 Notification — Urgency Enum")
struct G2UrgencyEnumTests {

    @Test("All 4 urgency cases exist")
    func allCases() {
        #expect(TestNotifUrgency.allCases.count == 4)
    }

    @Test("Comparable ordering: low < medium < high < critical")
    func ordering() {
        #expect(TestNotifUrgency.low < TestNotifUrgency.medium)
        #expect(TestNotifUrgency.medium < TestNotifUrgency.high)
        #expect(TestNotifUrgency.high < TestNotifUrgency.critical)
    }

    @Test("Sorting produces correct order")
    func sorting() {
        let shuffled: [TestNotifUrgency] = [.critical, .low, .high, .medium]
        let sorted = shuffled.sorted()
        #expect(sorted == [.low, .medium, .high, .critical])
    }

    @Test("Each urgency has unique icon")
    func uniqueIcons() {
        let icons = TestNotifUrgency.allCases.map(\.icon)
        #expect(Set(icons).count == 4)
    }

    @Test("Display names are capitalized")
    func displayNames() {
        #expect(TestNotifUrgency.critical.displayName == "Critical")
        #expect(TestNotifUrgency.low.displayName == "Low")
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for urgency in TestNotifUrgency.allCases {
            let data = try JSONEncoder().encode(urgency)
            let decoded = try JSONDecoder().decode(TestNotifUrgency.self, from: data)
            #expect(decoded == urgency)
        }
    }
}

@Suite("G2 Notification — Category Enum")
struct G2CategoryEnumTests {

    @Test("All 10 categories exist")
    func allCases() {
        #expect(TestNotifCategory.allCases.count == 10)
    }

    @Test("Each category has unique icon")
    func uniqueIcons() {
        let icons = TestNotifCategory.allCases.map(\.icon)
        // "bell.fill" is shared between .other and .medium urgency, but categories should still be unique
        #expect(Set(icons).count == 10)
    }

    @Test("Display names: 'other' is capitalized, others match rawValue")
    func displayNames() {
        #expect(TestNotifCategory.other.displayName == "Other")
        #expect(TestNotifCategory.messaging.displayName == "Messaging")
        #expect(TestNotifCategory.calendar.displayName == "Calendar")
        #expect(TestNotifCategory.finance.displayName == "Finance")
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestNotifCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == 10)
    }
}

@Suite("G2 Notification — Action Types")
struct G2ActionTypeTests {

    @Test("All 9 action types exist")
    func allTypes() {
        let all: [TestNotifActionType] = [
            .draftReply, .summarize, .prepareBriefing, .trackPackage,
            .logTransaction, .logHealthData, .clearNotification, .createTask, .setReminder
        ]
        let rawValues = all.map(\.rawValue)
        #expect(Set(rawValues).count == 9)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let action = TestNotifActionType.draftReply
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(TestNotifActionType.self, from: data)
        #expect(decoded == action)
    }
}

@Suite("G2 Notification — Urgency Classification")
struct G2UrgencyClassificationTests {

    @Test("Critical keywords detected: emergency, urgent, security breach")
    func criticalKeywords() {
        let cases: [(String?, String?)] = [
            ("EMERGENCY: System down", nil),
            ("Urgent action needed", nil),
            (nil, "Security breach detected on your account"),
            ("Alert", "Danger zone"),
            (nil, "Failed payment for subscription")
        ]
        for (title, body) in cases {
            let record = TestNotifRecord(appIdentifier: "any", title: title, body: body)
            #expect(TestNotifClassifier.determineUrgency(record) == .critical)
        }
    }

    @Test("High keywords detected: important, deadline, missed call")
    func highKeywords() {
        let cases: [(String?, String?)] = [
            ("Important update", nil),
            (nil, "Action required by tomorrow"),
            ("Deadline approaching", nil),
            (nil, "You have a missed call"),
            ("Payment due", nil),
            (nil, "Your subscription is expiring")
        ]
        for (title, body) in cases {
            let record = TestNotifRecord(appIdentifier: "any", title: title, body: body)
            #expect(TestNotifClassifier.determineUrgency(record) == .high)
        }
    }

    @Test("Medium keywords detected: message from, delivery, meeting")
    func mediumKeywords() {
        let cases: [(String?, String?)] = [
            ("New message from John", nil),
            (nil, "Reply to your comment"),
            ("Meeting at 3 PM", nil),
            (nil, "Your order has shipped"),
            ("Update available", nil),
            (nil, "You were mentioned you in a post")
        ]
        for (title, body) in cases {
            let record = TestNotifRecord(appIdentifier: "any", title: title, body: body)
            #expect(TestNotifClassifier.determineUrgency(record) == .medium)
        }
    }

    @Test("Default is low urgency")
    func defaultLow() {
        let record = TestNotifRecord(appIdentifier: "any", title: "Hello", body: "World")
        #expect(TestNotifClassifier.determineUrgency(record) == .low)
    }

    @Test("Nil title and body defaults to low")
    func nilTitleBody() {
        let record = TestNotifRecord(appIdentifier: "any")
        #expect(TestNotifClassifier.determineUrgency(record) == .low)
    }

    @Test("App settings urgency override applies")
    func urgencyOverride() {
        let record = TestNotifRecord(appIdentifier: "custom.app", title: "Hello")
        let settings = TestAppNotifSettings(urgencyOverride: .high)
        #expect(TestNotifClassifier.determineUrgency(record, appSettings: settings) == .high)
    }

    @Test("Critical keyword takes precedence over app override")
    func criticalOverridesApp() {
        let record = TestNotifRecord(appIdentifier: "any", title: "EMERGENCY")
        let settings = TestAppNotifSettings(urgencyOverride: .low)
        #expect(TestNotifClassifier.determineUrgency(record, appSettings: settings) == .critical)
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let record = TestNotifRecord(appIdentifier: "any", title: "EMERGENCY ALERT")
        #expect(TestNotifClassifier.determineUrgency(record) == .critical)
    }
}

@Suite("G2 Notification — Category Classification")
struct G2CategoryClassificationTests {

    @Test("Messaging apps detected")
    func messagingApps() {
        let apps = ["com.whatsapp", "org.telegram", "org.signal", "com.slack", "com.discord"]
        for app in apps {
            let record = TestNotifRecord(appIdentifier: app)
            #expect(TestNotifClassifier.determineCategory(record) == .messaging)
        }
    }

    @Test("Calendar detected by app ID")
    func calendarByApp() {
        let record = TestNotifRecord(appIdentifier: "com.apple.calendar")
        #expect(TestNotifClassifier.determineCategory(record) == .calendar)
    }

    @Test("Calendar detected by content keywords")
    func calendarByContent() {
        let record = TestNotifRecord(appIdentifier: "any", title: "Team meeting at 3 PM")
        #expect(TestNotifClassifier.determineCategory(record) == .calendar)
    }

    @Test("Email apps detected")
    func emailApps() {
        let apps = ["com.apple.mail", "com.google.gmail", "com.microsoft.outlook"]
        for app in apps {
            let record = TestNotifRecord(appIdentifier: app)
            #expect(TestNotifClassifier.determineCategory(record) == .email)
        }
    }

    @Test("Finance detected by keywords")
    func financeByKeywords() {
        let keywords = ["payment received", "new transaction", "balance update", "invoice #123"]
        for keyword in keywords {
            let record = TestNotifRecord(appIdentifier: "any", body: keyword)
            #expect(TestNotifClassifier.determineCategory(record) == .finance)
        }
    }

    @Test("Finance detected by app ID")
    func financeByApp() {
        let apps = ["com.revolut.app", "com.paypal.checkout", "ch.ubs.banking"]
        for app in apps {
            let record = TestNotifRecord(appIdentifier: app)
            #expect(TestNotifClassifier.determineCategory(record) == .finance)
        }
    }

    @Test("Health detected")
    func health() {
        let record = TestNotifRecord(appIdentifier: "com.apple.health", title: "Heart rate alert")
        #expect(TestNotifClassifier.determineCategory(record) == .health)
    }

    @Test("Delivery detected")
    func delivery() {
        let record = TestNotifRecord(appIdentifier: "any", body: "Your package has been delivered")
        #expect(TestNotifClassifier.determineCategory(record) == .delivery)
    }

    @Test("Social media apps detected")
    func socialMedia() {
        let apps = ["com.instagram", "com.facebook", "com.twitter", "com.tiktok",
                     "com.linkedin", "com.reddit"]
        for app in apps {
            let record = TestNotifRecord(appIdentifier: app)
            #expect(TestNotifClassifier.determineCategory(record) == .social)
        }
    }

    @Test("News detected")
    func news() {
        let record = TestNotifRecord(appIdentifier: "com.apple.news")
        #expect(TestNotifClassifier.determineCategory(record) == .news)
    }

    @Test("Breaking news by content (no calendar keywords)")
    func breakingNews() {
        // Note: "event" triggers calendar category first in priority order
        // So use a news title without calendar keywords
        let record = TestNotifRecord(appIdentifier: "any", title: "Breaking: Earthquake strikes")
        #expect(TestNotifClassifier.determineCategory(record) == .news)
    }

    @Test("System apps detected")
    func systemApps() {
        let record = TestNotifRecord(appIdentifier: "com.apple.finder")
        #expect(TestNotifClassifier.determineCategory(record) == .system)
    }

    @Test("Unknown app defaults to other")
    func unknownApp() {
        let record = TestNotifRecord(appIdentifier: "com.unknown.app", title: "Hello")
        #expect(TestNotifClassifier.determineCategory(record) == .other)
    }
}

@Suite("G2 Notification — Suggested Actions")
struct G2SuggestedActionsTests {

    @Test("Messaging suggests draft reply")
    func messagingSuggestsDraftReply() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .medium, category: .messaging)
        #expect(actions.contains(.draftReply))
        #expect(actions.contains(.clearNotification)) // Always present
    }

    @Test("Calendar suggests prepare briefing")
    func calendarSuggestsBriefing() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .medium, category: .calendar)
        #expect(actions.contains(.prepareBriefing))
    }

    @Test("Email suggests summarize")
    func emailSuggestsSummarize() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .low, category: .email)
        #expect(actions.contains(.summarize))
    }

    @Test("High urgency email also suggests draft reply")
    func highUrgencyEmailSuggestsDraft() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .high, category: .email)
        #expect(actions.contains(.summarize))
        #expect(actions.contains(.draftReply))
    }

    @Test("Critical urgency email suggests draft reply")
    func criticalEmailSuggestsDraft() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .critical, category: .email)
        #expect(actions.contains(.draftReply))
    }

    @Test("Delivery suggests track package")
    func deliverySuggestsTrack() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .medium, category: .delivery)
        #expect(actions.contains(.trackPackage))
    }

    @Test("Finance suggests log transaction")
    func financeSuggestsLog() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .medium, category: .finance)
        #expect(actions.contains(.logTransaction))
    }

    @Test("Health suggests log health data")
    func healthSuggestsLog() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .medium, category: .health)
        #expect(actions.contains(.logHealthData))
    }

    @Test("Other category only gets clear notification")
    func otherOnlyClear() {
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: .low, category: .other)
        #expect(actions == [.clearNotification])
    }

    @Test("Clear notification always present")
    func clearAlwaysPresent() {
        for category in TestNotifCategory.allCases {
            let actions = TestNotifClassifier.determineSuggestedActions(urgency: .medium, category: category)
            #expect(actions.contains(.clearNotification))
        }
    }
}

@Suite("G2 Notification — Auto-Action Logic")
struct G2AutoActionTests {

    @Test("Auto-action fires when confidence >= threshold and no approval needed")
    func autoActionFires() {
        let result = TestNotifClassifier.shouldAutoAction(
            actionConfidence: 0.9,
            requiresApproval: false,
            threshold: 0.8,
            autoActionEnabled: true,
            appAutoEnabled: false
        )
        #expect(result == true)
    }

    @Test("Auto-action blocked when below threshold")
    func belowThreshold() {
        let result = TestNotifClassifier.shouldAutoAction(
            actionConfidence: 0.7,
            requiresApproval: false,
            threshold: 0.8,
            autoActionEnabled: true,
            appAutoEnabled: false
        )
        #expect(result == false)
    }

    @Test("Auto-action blocked when requires approval")
    func requiresApproval() {
        let result = TestNotifClassifier.shouldAutoAction(
            actionConfidence: 0.95,
            requiresApproval: true,
            threshold: 0.8,
            autoActionEnabled: true,
            appAutoEnabled: false
        )
        #expect(result == false)
    }

    @Test("Auto-action blocked when disabled globally")
    func disabledGlobally() {
        let result = TestNotifClassifier.shouldAutoAction(
            actionConfidence: 0.95,
            requiresApproval: false,
            threshold: 0.8,
            autoActionEnabled: false,
            appAutoEnabled: false
        )
        #expect(result == false)
    }

    @Test("App-level auto-action overrides global disable")
    func appOverride() {
        let result = TestNotifClassifier.shouldAutoAction(
            actionConfidence: 0.9,
            requiresApproval: false,
            threshold: 0.8,
            autoActionEnabled: false,
            appAutoEnabled: true
        )
        #expect(result == true)
    }

    @Test("Exact threshold passes")
    func exactThreshold() {
        let result = TestNotifClassifier.shouldAutoAction(
            actionConfidence: 0.8,
            requiresApproval: false,
            threshold: 0.8,
            autoActionEnabled: true,
            appAutoEnabled: false
        )
        #expect(result == true)
    }
}

@Suite("G2 Notification — App Settings")
struct G2AppSettingsTests {

    @Test("Default settings")
    func defaults() {
        let settings = TestAppNotifSettings()
        #expect(settings.enabled == true)
        #expect(settings.autoActionsEnabled == false)
        #expect(settings.urgencyOverride == nil)
        #expect(settings.mutedUntil == nil)
    }

    @Test("Custom settings")
    func custom() {
        let future = Date().addingTimeInterval(3600)
        let settings = TestAppNotifSettings(
            enabled: false,
            autoActionsEnabled: true,
            urgencyOverride: .high,
            mutedUntil: future
        )
        #expect(settings.enabled == false)
        #expect(settings.autoActionsEnabled == true)
        #expect(settings.urgencyOverride == .high)
        #expect(settings.mutedUntil != nil)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let settings = TestAppNotifSettings(
            enabled: true,
            autoActionsEnabled: true,
            urgencyOverride: .critical,
            mutedUntil: Date()
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TestAppNotifSettings.self, from: data)
        #expect(decoded.enabled == settings.enabled)
        #expect(decoded.autoActionsEnabled == settings.autoActionsEnabled)
        #expect(decoded.urgencyOverride == settings.urgencyOverride)
    }

    @Test("Nil urgency override in Codable")
    func nilOverrideCodable() throws {
        let settings = TestAppNotifSettings()
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TestAppNotifSettings.self, from: data)
        #expect(decoded.urgencyOverride == nil)
    }
}

@Suite("G2 Notification — Clearance")
struct G2ClearanceTests {

    @Test("Clearance has correct ID")
    func clearanceID() {
        let notifID = UUID()
        let clearance = TestNotifClearance(
            notificationID: notifID,
            appIdentifier: "com.whatsapp",
            clearedAt: Date(),
            clearedBy: "Mac Studio",
            deviceID: "device-123"
        )
        #expect(clearance.id == notifID)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let clearance = TestNotifClearance(
            notificationID: UUID(),
            appIdentifier: "com.slack",
            clearedAt: Date(),
            clearedBy: "iPhone",
            deviceID: "device-456"
        )
        let data = try JSONEncoder().encode(clearance)
        let decoded = try JSONDecoder().decode(TestNotifClearance.self, from: data)
        #expect(decoded.notificationID == clearance.notificationID)
        #expect(decoded.appIdentifier == clearance.appIdentifier)
        #expect(decoded.clearedBy == clearance.clearedBy)
        #expect(decoded.deviceID == clearance.deviceID)
    }
}

@Suite("G2 Notification — Statistics")
struct G2StatsTests {

    @Test("Empty stats")
    func emptyStats() {
        let stats = TestNotifStats(
            totalClassified: 0,
            byUrgency: [:],
            byCategory: [:],
            totalCleared: 0,
            totalActioned: 0,
            autoActionRate: 0
        )
        #expect(stats.totalClassified == 0)
        #expect(stats.autoActionRate == 0)
    }

    @Test("Stats with data")
    func statsWithData() {
        let stats = TestNotifStats(
            totalClassified: 100,
            byUrgency: [.critical: 5, .high: 15, .medium: 30, .low: 50],
            byCategory: [.messaging: 40, .email: 30, .finance: 20, .other: 10],
            totalCleared: 80,
            totalActioned: 20,
            autoActionRate: 0.2
        )
        #expect(stats.totalClassified == 100)
        #expect(stats.byUrgency[.critical] == 5)
        #expect(stats.byCategory[.messaging] == 40)
        #expect(stats.totalCleared == 80)
        #expect(stats.autoActionRate == 0.2)
    }

    @Test("Auto-action rate computed correctly")
    func autoActionRate() {
        let actioned = 15
        let total = 50
        let rate = total > 0 ? Double(actioned) / Double(total) : 0
        #expect(rate == 0.3)
    }

    @Test("Auto-action rate zero when no classified")
    func autoActionRateZero() {
        let rate = 0 > 0 ? Double(5) / Double(0) : 0.0
        #expect(rate == 0)
    }
}

@Suite("G2 Notification — End-to-End Classification")
struct G2EndToEndTests {

    @Test("WhatsApp message: messaging, medium, draft reply")
    func whatsappMessage() {
        let record = TestNotifRecord(
            appIdentifier: "net.whatsapp.WhatsApp",
            title: "New message from John",
            body: "Hey, can we meet tomorrow?"
        )
        let urgency = TestNotifClassifier.determineUrgency(record)
        let category = TestNotifClassifier.determineCategory(record)
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: urgency, category: category)

        #expect(urgency == .medium) // "new message"
        #expect(category == .messaging)
        #expect(actions.contains(.draftReply))
    }

    @Test("Bank payment: finance, critical")
    func bankPayment() {
        let record = TestNotifRecord(
            appIdentifier: "com.revolut.app",
            title: "Failed payment",
            body: "Your payment of CHF 50 failed"
        )
        let urgency = TestNotifClassifier.determineUrgency(record)
        let category = TestNotifClassifier.determineCategory(record)

        #expect(urgency == .critical) // "failed payment"
        #expect(category == .finance) // "revolut" app + "payment" keyword
    }

    @Test("Package delivered: delivery, medium, track")
    func packageDelivered() {
        let record = TestNotifRecord(
            appIdentifier: "com.laposte.app",
            title: "Package delivered",
            body: "Your package has been delivered to your doorstep"
        )
        let urgency = TestNotifClassifier.determineUrgency(record)
        let category = TestNotifClassifier.determineCategory(record)
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: urgency, category: category)

        #expect(category == .delivery)
        #expect(actions.contains(.trackPackage))
    }

    @Test("Calendar meeting: calendar, medium, briefing")
    func calendarMeeting() {
        let record = TestNotifRecord(
            appIdentifier: "com.apple.calendar",
            title: "Meeting in 15 minutes",
            body: "Team standup appointment"
        )
        let urgency = TestNotifClassifier.determineUrgency(record)
        let category = TestNotifClassifier.determineCategory(record)
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: urgency, category: category)

        #expect(urgency == .medium) // "meeting" + "appointment"
        #expect(category == .calendar)
        #expect(actions.contains(.prepareBriefing))
    }

    @Test("Instagram like: social, low, only clear")
    func instagramLike() {
        let record = TestNotifRecord(
            appIdentifier: "com.instagram.app",
            title: "user123 liked your photo"
        )
        let urgency = TestNotifClassifier.determineUrgency(record)
        let category = TestNotifClassifier.determineCategory(record)
        let actions = TestNotifClassifier.determineSuggestedActions(urgency: urgency, category: category)

        #expect(urgency == .low)
        #expect(category == .social)
        #expect(actions == [.clearNotification])
    }
}
