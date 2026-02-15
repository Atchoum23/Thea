// LearningManager.swift
// Thea — Learning goal tracking and progress management
//
// Tracks learning goals, courses, study sessions, and progress
// with streak tracking and skill-level assessment.

import Foundation
import OSLog

private let learnLogger = Logger(subsystem: "ai.thea.app", category: "LearningManager")

// MARK: - Models

/// A learning goal with progress tracking.
struct LearningGoal: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var category: LearningCategory
    var status: LearningStatus
    var targetDate: Date?
    var progressPercent: Double
    var resources: [LearningResource]
    var studySessions: [StudySession]
    var tags: [String]
    var priority: LearningPriority
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String, description: String = "", category: LearningCategory = .technology,
        status: LearningStatus = .notStarted, targetDate: Date? = nil,
        priority: LearningPriority = .medium, tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.status = status
        self.targetDate = targetDate
        self.progressPercent = 0
        self.resources = []
        self.studySessions = []
        self.tags = tags
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var totalStudyMinutes: Int {
        studySessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalStudyHours: Double {
        Double(totalStudyMinutes) / 60.0
    }

    var currentStreak: Int {
        let cal = Calendar.current
        let sortedDates = Set(studySessions.map { cal.startOfDay(for: $0.date) }).sorted().reversed()
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

    var isOverdue: Bool {
        guard let target = targetDate else { return false }
        return target < Date() && status != .completed
    }
}

enum LearningCategory: String, Codable, Sendable, CaseIterable {
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

enum LearningStatus: String, Codable, Sendable, CaseIterable {
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

enum LearningPriority: String, Codable, Sendable, CaseIterable, Comparable {
    case low, medium, high

    var score: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    static func < (lhs: LearningPriority, rhs: LearningPriority) -> Bool {
        lhs.score < rhs.score
    }
}

/// A resource associated with a learning goal.
struct LearningResource: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var type: ResourceType
    var url: String?
    var isCompleted: Bool

    enum ResourceType: String, Codable, Sendable, CaseIterable {
        case book, course, video, article, podcast, tutorial, documentation

        var icon: String {
            switch self {
            case .book: "book"
            case .course: "graduationcap"
            case .video: "play.rectangle"
            case .article: "doc.text"
            case .podcast: "headphones"
            case .tutorial: "list.bullet.rectangle"
            case .documentation: "doc.append"
            }
        }
    }

    init(title: String, type: ResourceType = .article, url: String? = nil, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.url = url
        self.isCompleted = isCompleted
    }
}

/// A study session entry.
struct StudySession: Codable, Sendable, Identifiable {
    let id: UUID
    var date: Date
    var durationMinutes: Int
    var notes: String
    var rating: Int // 1-5

    init(date: Date = Date(), durationMinutes: Int, notes: String = "", rating: Int = 3) {
        self.id = UUID()
        self.date = date
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.rating = min(max(rating, 1), 5)
    }
}

// MARK: - Manager

@MainActor
final class LearningManager: ObservableObject {
    static let shared = LearningManager()

    @Published private(set) var goals: [LearningGoal] = []

    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/LifeManagement", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("learning.json")
        loadState()
    }

    // MARK: - CRUD

    func addGoal(_ goal: LearningGoal) {
        goals.append(goal)
        save()
        learnLogger.info("Added learning goal: \(goal.title)")
    }

    func updateGoal(_ goal: LearningGoal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            var updated = goal
            updated.updatedAt = Date()
            goals[idx] = updated
            save()
        }
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        save()
    }

    func addStudySession(goalID: UUID, session: StudySession) {
        if let idx = goals.firstIndex(where: { $0.id == goalID }) {
            goals[idx].studySessions.append(session)
            goals[idx].updatedAt = Date()
            if goals[idx].status == .notStarted {
                goals[idx].status = .inProgress
            }
            save()
        }
    }

    func addResource(goalID: UUID, resource: LearningResource) {
        if let idx = goals.firstIndex(where: { $0.id == goalID }) {
            goals[idx].resources.append(resource)
            goals[idx].updatedAt = Date()
            save()
        }
    }

    // MARK: - Analytics

    var activeGoals: [LearningGoal] {
        goals.filter { $0.status == .inProgress || $0.status == .notStarted }
            .sorted { $0.priority > $1.priority }
    }

    var completedGoals: [LearningGoal] {
        goals.filter { $0.status == .completed }
    }

    var totalStudyHours: Double {
        goals.reduce(0) { $0 + $1.totalStudyHours }
    }

    var longestStreak: Int {
        goals.map(\.currentStreak).max() ?? 0
    }

    var goalsByCategory: [LearningCategory: [LearningGoal]] {
        Dictionary(grouping: goals, by: \.category)
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(goals) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([LearningGoal].self, from: data) {
            goals = loaded
        }
    }
}
