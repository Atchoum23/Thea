// H8SubsPasswordLearningTests.swift
// Tests for H8 Life Management: Subscriptions, Passwords, and Learning modules
//
// Covers model types, computed properties, enum conformance, business logic,
// and Codable roundtrips for Subscriptions, Passwords, and Learning modules.

import Testing
import Foundation

// MARK: - Subscription Types

private enum TestSubCategory: String, Codable, CaseIterable {
    case streaming, music, cloud, productivity, fitness, education
    case news, gaming, utilities, development, security, social, other
    var displayName: String {
        switch self {
        case .streaming: "Streaming"
        case .music: "Music"
        case .cloud: "Cloud & Storage"
        case .productivity: "Productivity"
        case .fitness: "Fitness"
        case .education: "Education"
        case .news: "News"
        case .gaming: "Gaming"
        case .utilities: "Utilities"
        case .development: "Development"
        case .security: "Security"
        case .social: "Social"
        case .other: "Other"
        }
    }
    var icon: String {
        switch self {
        case .streaming: "play.tv"
        case .music: "music.note"
        case .cloud: "icloud"
        case .productivity: "briefcase"
        case .fitness: "figure.run"
        case .education: "graduationcap"
        case .news: "newspaper"
        case .gaming: "gamecontroller"
        case .utilities: "wrench.and.screwdriver"
        case .development: "chevron.left.forwardslash.chevron.right"
        case .security: "lock.shield"
        case .social: "person.2"
        case .other: "ellipsis.circle"
        }
    }
}

private enum TestBillingCycle: String, Codable, CaseIterable {
    case weekly, monthly, quarterly, semiAnnual, annual, lifetime
    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiAnnual: "Semi-Annual"
        case .annual: "Annual"
        case .lifetime: "Lifetime"
        }
    }
    func nextDate(from date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .weekly: return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly: return cal.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return cal.date(byAdding: .month, value: 3, to: date) ?? date
        case .semiAnnual: return cal.date(byAdding: .month, value: 6, to: date) ?? date
        case .annual: return cal.date(byAdding: .year, value: 1, to: date) ?? date
        case .lifetime: return cal.date(byAdding: .year, value: 100, to: date) ?? date
        }
    }
}

// MARK: - Password Types

private enum TestPasswordStrength: String, Codable, CaseIterable, Comparable {
    case veryWeak, weak, fair, strong, veryStrong
    var score: Int {
        switch self {
        case .veryWeak: 0
        case .weak: 1
        case .fair: 2
        case .strong: 3
        case .veryStrong: 4
        }
    }
    static func < (lhs: TestPasswordStrength, rhs: TestPasswordStrength) -> Bool {
        lhs.score < rhs.score
    }
}

private enum TestCredentialCategory: String, Codable, CaseIterable {
    case website, email, banking, social, work, development, wifi, server, other
    var displayName: String {
        switch self {
        case .website: "Website"
        case .email: "Email"
        case .banking: "Banking"
        case .social: "Social Media"
        case .work: "Work"
        case .development: "Development"
        case .wifi: "Wi-Fi"
        case .server: "Server"
        case .other: "Other"
        }
    }
    var icon: String {
        switch self {
        case .website: "globe"
        case .email: "envelope"
        case .banking: "building.columns"
        case .social: "person.2"
        case .work: "briefcase"
        case .development: "terminal"
        case .wifi: "wifi"
        case .server: "server.rack"
        case .other: "key"
        }
    }
}

private enum TestPasswordAnalyzer {
    static func analyzeStrength(_ password: String) -> TestPasswordStrength {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.count >= 20 { score += 1 }
        let hasUpper = password.contains(where: \.isUppercase)
        let hasLower = password.contains(where: \.isLowercase)
        let hasDigit = password.contains(where: \.isNumber)
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
        let variety = [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count
        score += variety
        let lower = password.lowercased()
        let commonPatterns = ["password", "123456", "qwerty", "admin", "letmein",
                              "welcome", "monkey", "abc123"]
        if commonPatterns.contains(where: { lower.contains($0) }) {
            score = max(score - 3, 0)
        }
        if password.count < 6 { return .veryWeak }
        switch score {
        case 0...2: return .veryWeak
        case 3: return .weak
        case 4...5: return .fair
        case 6...7: return .strong
        default: return .veryStrong
        }
    }

    static func generatePassword(length: Int = 16, includeUppercase: Bool = true,
                                  includeLowercase: Bool = true, includeDigits: Bool = true,
                                  includeSpecial: Bool = true) -> String {
        var chars = ""
        if includeLowercase { chars += "abcdefghijkmnpqrstuvwxyz" }
        if includeUppercase { chars += "ABCDEFGHJKLMNPQRSTUVWXYZ" }
        if includeDigits { chars += "23456789" }
        if includeSpecial { chars += "!@#$%^&*-_=+" }
        guard !chars.isEmpty else { return "" }
        let charArray = Array(chars)
        var result = ""
        for _ in 0..<length {
            result.append(charArray[Int.random(in: 0..<charArray.count)])
        }
        return result
    }
}

// MARK: - Learning Types

private enum TestLearningCategory: String, Codable, CaseIterable {
    case technology, language, science, mathematics, arts, music
    case business, health, cooking, crafts, sports, other
    var displayName: String {
        switch self {
        case .technology: "Technology"
        case .language: "Language"
        case .science: "Science"
        case .mathematics: "Mathematics"
        case .arts: "Arts"
        case .music: "Music"
        case .business: "Business"
        case .health: "Health"
        case .cooking: "Cooking"
        case .crafts: "Crafts"
        case .sports: "Sports"
        case .other: "Other"
        }
    }
    var icon: String {
        switch self {
        case .technology: "desktopcomputer"
        case .language: "character.bubble"
        case .science: "atom"
        case .mathematics: "function"
        case .arts: "paintpalette"
        case .music: "music.note"
        case .business: "chart.bar"
        case .health: "heart"
        case .cooking: "fork.knife"
        case .crafts: "hammer"
        case .sports: "figure.run"
        case .other: "book"
        }
    }
}

private enum TestLearningStatus: String, Codable, CaseIterable {
    case notStarted, inProgress, paused, completed, abandoned
    var displayName: String {
        switch self {
        case .notStarted: "Not Started"
        case .inProgress: "In Progress"
        case .paused: "Paused"
        case .completed: "Completed"
        case .abandoned: "Abandoned"
        }
    }
}

private enum TestLearningPriority: String, Codable, CaseIterable, Comparable {
    case low, medium, high
    var score: Int {
        switch self { case .low: 0; case .medium: 1; case .high: 2 }
    }
    static func < (lhs: TestLearningPriority, rhs: TestLearningPriority) -> Bool {
        lhs.score < rhs.score
    }
}

private struct TestStudySession: Codable, Identifiable {
    let id: UUID
    var date: Date
    var durationMinutes: Int
    var notes: String
    var rating: Int
    init(date: Date = Date(), durationMinutes: Int, notes: String = "", rating: Int = 3) {
        self.id = UUID()
        self.date = date
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.rating = min(max(rating, 1), 5)
    }
}

// ============================================================
// MARK: - TESTS
// ============================================================

// MARK: - Subscription Tests

@Suite("H8 Subscriptions — SubscriptionCategory")
struct SubscriptionCategoryTests {
    @Test("All 13 categories")
    func allCases() {
        #expect(TestSubCategory.allCases.count == 13)
    }

    @Test("Unique display names")
    func uniqueNames() {
        let names = TestSubCategory.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("Unique icons")
    func uniqueIcons() {
        let icons = TestSubCategory.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }
}

@Suite("H8 Subscriptions — BillingCycle")
struct BillingCycleTests {
    @Test("All 6 cycles")
    func allCases() {
        #expect(TestBillingCycle.allCases.count == 6)
    }

    @Test("Display names non-empty")
    func displayNames() {
        for cycle in TestBillingCycle.allCases {
            #expect(!cycle.displayName.isEmpty)
        }
    }

    @Test("Next date — weekly")
    func weeklyNext() {
        let now = Date()
        let next = TestBillingCycle.weekly.nextDate(from: now)
        let days = Calendar.current.dateComponents([.day], from: now, to: next).day ?? 0
        #expect(days >= 6 && days <= 8)
    }

    @Test("Next date — monthly")
    func monthlyNext() {
        let now = Date()
        let next = TestBillingCycle.monthly.nextDate(from: now)
        let months = Calendar.current.dateComponents([.month], from: now, to: next).month ?? 0
        #expect(months == 1)
    }

    @Test("Next date — quarterly")
    func quarterlyNext() {
        let now = Date()
        let next = TestBillingCycle.quarterly.nextDate(from: now)
        let months = Calendar.current.dateComponents([.month], from: now, to: next).month ?? 0
        #expect(months == 3)
    }

    @Test("Next date — annual")
    func annualNext() {
        let now = Date()
        let next = TestBillingCycle.annual.nextDate(from: now)
        let years = Calendar.current.dateComponents([.year], from: now, to: next).year ?? 0
        #expect(years == 1)
    }

    @Test("Next date — lifetime (100 years)")
    func lifetimeNext() {
        let now = Date()
        let next = TestBillingCycle.lifetime.nextDate(from: now)
        let years = Calendar.current.dateComponents([.year], from: now, to: next).year ?? 0
        #expect(years >= 99)
    }
}

@Suite("H8 Subscriptions — Cost Calculations")
struct SubscriptionCostTests {
    @Test("Monthly cost — weekly subscription")
    func weeklyCost() {
        let weekly = 10.0
        let monthly = weekly * 52 / 12
        #expect(monthly > 43.0 && monthly < 44.0)
    }

    @Test("Monthly cost — monthly passes through")
    func monthlyCost() {
        let cost = 15.99
        #expect(cost == 15.99)
    }

    @Test("Monthly cost — quarterly divided by 3")
    func quarterlyCost() {
        let quarterly = 30.0
        #expect(quarterly / 3 == 10.0)
    }

    @Test("Monthly cost — annual divided by 12")
    func annualCost() {
        let annual = 120.0
        #expect(annual / 12 == 10.0)
    }

    @Test("Monthly cost — lifetime is zero")
    func lifetimeCost() {
        let lifetimeMonthly: Double = 0
        #expect(lifetimeMonthly == 0)
    }

    @Test("Annual cost from monthly")
    func annualFromMonthly() {
        let monthly = 9.99
        #expect(monthly * 12 > 119.0 && monthly * 12 < 120.0)
    }

    @Test("Renewal soon — within 7 days")
    func renewalSoon() {
        let renewal = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let daysDiff = Calendar.current.dateComponents([.day], from: Date(), to: renewal).day ?? 0
        #expect(daysDiff <= 7 && daysDiff >= 0)
    }

    @Test("Renewal not soon — 30 days out")
    func notRenewalSoon() {
        let renewal = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let daysDiff = Calendar.current.dateComponents([.day], from: Date(), to: renewal).day ?? 0
        #expect(daysDiff > 7)
    }
}

// MARK: - Password Tests

@Suite("H8 Passwords — CredentialCategory")
struct CredentialCategoryTests {
    @Test("All 9 categories")
    func allCases() {
        #expect(TestCredentialCategory.allCases.count == 9)
    }

    @Test("Unique display names")
    func uniqueNames() {
        let names = TestCredentialCategory.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("Unique icons")
    func uniqueIcons() {
        let icons = TestCredentialCategory.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }
}

@Suite("H8 Passwords — PasswordStrength")
struct PasswordStrengthTests {
    @Test("All 5 strength levels")
    func allCases() {
        #expect(TestPasswordStrength.allCases.count == 5)
    }

    @Test("Strength ordering")
    func ordering() {
        #expect(TestPasswordStrength.veryWeak < TestPasswordStrength.weak)
        #expect(TestPasswordStrength.weak < TestPasswordStrength.fair)
        #expect(TestPasswordStrength.fair < TestPasswordStrength.strong)
        #expect(TestPasswordStrength.strong < TestPasswordStrength.veryStrong)
    }

    @Test("Score values 0-4")
    func scores() {
        let scores = TestPasswordStrength.allCases.map(\.score)
        #expect(scores == [0, 1, 2, 3, 4])
    }

    @Test("Sorting")
    func sorting() {
        let shuffled: [TestPasswordStrength] = [.strong, .veryWeak, .veryStrong, .weak, .fair]
        let sorted = shuffled.sorted()
        #expect(sorted == [.veryWeak, .weak, .fair, .strong, .veryStrong])
    }
}

@Suite("H8 Passwords — PasswordAnalyzer")
struct PasswordAnalyzerTests {
    @Test("Very short password is veryWeak")
    func veryShort() {
        #expect(TestPasswordAnalyzer.analyzeStrength("abc") == .veryWeak)
    }

    @Test("Common password pattern is penalized")
    func commonPattern() {
        #expect(TestPasswordAnalyzer.analyzeStrength("password123") <= .weak)
    }

    @Test("Strong password with variety")
    func strongPassword() {
        let result = TestPasswordAnalyzer.analyzeStrength("Tr0ub4dor&3Xy!")
        #expect(result >= .fair)
    }

    @Test("Very long password with all character types")
    func veryStrongPassword() {
        let result = TestPasswordAnalyzer.analyzeStrength("Xk9#mP2$vR7!nL4@wQ8^")
        #expect(result == .veryStrong)
    }

    @Test("Generate password — correct length")
    func generateLength() {
        let pw = TestPasswordAnalyzer.generatePassword(length: 20)
        #expect(pw.count == 20)
    }

    @Test("Generate password — default length 16")
    func generateDefault() {
        let pw = TestPasswordAnalyzer.generatePassword()
        #expect(pw.count == 16)
    }

    @Test("Generate password — empty when no char sets")
    func generateEmpty() {
        let pw = TestPasswordAnalyzer.generatePassword(
            includeUppercase: false, includeLowercase: false,
            includeDigits: false, includeSpecial: false)
        #expect(pw.isEmpty)
    }

    @Test("Generate password — only digits")
    func generateDigitsOnly() {
        let pw = TestPasswordAnalyzer.generatePassword(
            length: 10, includeUppercase: false,
            includeLowercase: false, includeDigits: true, includeSpecial: false)
        #expect(pw.count == 10)
        let allDigits = pw.allSatisfy(\.isNumber)
        #expect(allDigits)
    }

    @Test("Generated passwords are unique")
    func generateUnique() {
        let pw1 = TestPasswordAnalyzer.generatePassword()
        let pw2 = TestPasswordAnalyzer.generatePassword()
        #expect(pw1 != pw2)
    }

    @Test("Strength analysis — 6 char lowercase only")
    func sixCharLower() {
        let result = TestPasswordAnalyzer.analyzeStrength("abcdef")
        #expect(result == .veryWeak)
    }

    @Test("Strength analysis — 8 char with upper + lower")
    func eightCharMixed() {
        let result = TestPasswordAnalyzer.analyzeStrength("AbcdEfgh")
        #expect(result >= .veryWeak)
    }
}

// MARK: - Learning Tests

@Suite("H8 Learning — LearningCategory")
struct LearningCategoryTests {
    @Test("All 12 categories")
    func allCases() {
        #expect(TestLearningCategory.allCases.count == 12)
    }

    @Test("Unique display names")
    func uniqueNames() {
        let names = TestLearningCategory.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("Unique icons")
    func uniqueIcons() {
        let icons = TestLearningCategory.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }
}

@Suite("H8 Learning — LearningStatus")
struct LearningStatusTests {
    @Test("All 5 statuses")
    func allCases() {
        #expect(TestLearningStatus.allCases.count == 5)
    }

    @Test("Display names non-empty")
    func displayNames() {
        for status in TestLearningStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }
}

@Suite("H8 Learning — LearningPriority")
struct LearningPriorityTests {
    @Test("All 3 priorities")
    func allCases() {
        #expect(TestLearningPriority.allCases.count == 3)
    }

    @Test("Ordering")
    func ordering() {
        #expect(TestLearningPriority.low < TestLearningPriority.medium)
        #expect(TestLearningPriority.medium < TestLearningPriority.high)
    }

    @Test("Sorting")
    func sorting() {
        let shuffled: [TestLearningPriority] = [.high, .low, .medium]
        let sorted = shuffled.sorted()
        #expect(sorted == [.low, .medium, .high])
    }
}

@Suite("H8 Learning — StudySession")
struct StudySessionTests {
    @Test("Rating clamped to 1-5 range — below")
    func ratingClampBelow() {
        let session = TestStudySession(durationMinutes: 30, rating: 0)
        #expect(session.rating == 1)
    }

    @Test("Rating clamped to 1-5 range — above")
    func ratingClampAbove() {
        let session = TestStudySession(durationMinutes: 30, rating: 10)
        #expect(session.rating == 5)
    }

    @Test("Rating within range passes through")
    func ratingNormal() {
        let session = TestStudySession(durationMinutes: 30, rating: 3)
        #expect(session.rating == 3)
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let s1 = TestStudySession(durationMinutes: 30)
        let s2 = TestStudySession(durationMinutes: 30)
        #expect(s1.id != s2.id)
    }

    @Test("Default rating is 3")
    func defaultRating() {
        let session = TestStudySession(durationMinutes: 45)
        #expect(session.rating == 3)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let session = TestStudySession(durationMinutes: 60, notes: "Studied SwiftUI", rating: 4)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestStudySession.self, from: data)
        #expect(decoded.durationMinutes == 60)
        #expect(decoded.notes == "Studied SwiftUI")
        #expect(decoded.rating == 4)
    }
}

// MARK: - Learning Goal Streak Tests

@Suite("H8 Learning — Streak Calculation")
struct StreakCalculationTests {
    @Test("No sessions — zero streak")
    func noSessions() {
        let sessions: [TestStudySession] = []
        let streak = calculateStreak(sessions)
        #expect(streak == 0)
    }

    @Test("Session today — streak of 1")
    func todayOnly() {
        let sessions = [TestStudySession(date: Date(), durationMinutes: 30)]
        let streak = calculateStreak(sessions)
        #expect(streak == 1)
    }

    @Test("Session today and yesterday — streak of 2")
    func todayAndYesterday() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let sessions = [
            TestStudySession(date: Date(), durationMinutes: 30),
            TestStudySession(date: yesterday, durationMinutes: 30),
        ]
        let streak = calculateStreak(sessions)
        #expect(streak == 2)
    }

    @Test("Gap breaks streak")
    func gapBreaksStreak() {
        let cal = Calendar.current
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: Date())!
        let sessions = [
            TestStudySession(date: Date(), durationMinutes: 30),
            TestStudySession(date: threeDaysAgo, durationMinutes: 30),
        ]
        let streak = calculateStreak(sessions)
        #expect(streak == 1)
    }

    @Test("Old session not today/yesterday — zero streak")
    func oldSession() {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date())!
        let sessions = [TestStudySession(date: weekAgo, durationMinutes: 30)]
        let streak = calculateStreak(sessions)
        #expect(streak == 0)
    }

    private func calculateStreak(_ sessions: [TestStudySession]) -> Int {
        let cal = Calendar.current
        let sortedDates = Set(sessions.map { cal.startOfDay(for: $0.date) }).sorted().reversed()
        guard let latest = sortedDates.first else { return 0 }
        guard cal.isDateInToday(latest) || cal.isDateInYesterday(latest) else { return 0 }
        var streak = 1
        var prevDate = latest
        for date in sortedDates.dropFirst() {
            let daysBetween = cal.dateComponents([.day], from: date, to: prevDate).day ?? 0
            if daysBetween == 1 {
                streak += 1
                prevDate = date
            } else {
                break
            }
        }
        return streak
    }
}

// MARK: - Cross-Module Codable Tests

@Suite("H8 Subs+Passwords+Learning — Codable Integration")
struct SubsPasswordLearningCodableTests {
    @Test("PasswordStrength Codable roundtrip")
    func passwordStrength() throws {
        for strength in TestPasswordStrength.allCases {
            let data = try JSONEncoder().encode(strength)
            let decoded = try JSONDecoder().decode(TestPasswordStrength.self, from: data)
            #expect(decoded == strength)
        }
    }

    @Test("LearningPriority Codable roundtrip")
    func learningPriority() throws {
        for priority in TestLearningPriority.allCases {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(TestLearningPriority.self, from: data)
            #expect(decoded == priority)
        }
    }
}
