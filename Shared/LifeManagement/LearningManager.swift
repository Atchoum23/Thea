// LearningManager.swift
// Thea — Learning goal tracking and progress management
//
// Tracks learning goals, courses, study sessions, and progress
// with streak tracking and skill-level assessment.

import Foundation
import OSLog

private let learnLogger = Logger(subsystem: "ai.thea.app", category: "LearningTracker")

// MARK: - Models

/// A learning goal with progress tracking.
struct TrackedLearningGoal: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var category: LearningCategory
    var status: LearningStatus
    var targetDate: Date?
    var progressPercent: Double
    var resources: [TrackedLearningResource]
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
struct TrackedLearningResource: Codable, Sendable, Identifiable {
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

    // periphery:ignore - Reserved: init(title:type:url:isCompleted:) initializer — reserved for future feature activation
    init(title: String, type: ResourceType = .article, url: String? = nil, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.url = url
        // periphery:ignore - Reserved: init(title:type:url:isCompleted:) initializer reserved for future feature activation
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

    // periphery:ignore - Reserved: init(date:durationMinutes:notes:rating:) initializer — reserved for future feature activation
    init(date: Date = Date(), durationMinutes: Int, notes: String = "", rating: Int = 3) {
        self.id = UUID()
        self.date = date
        self.durationMinutes = durationMinutes
        // periphery:ignore - Reserved: init(date:durationMinutes:notes:rating:) initializer reserved for future feature activation
        self.notes = notes
        self.rating = min(max(rating, 1), 5)
    }
}

// MARK: - Manager

@MainActor
final class LearningTracker: ObservableObject {
    static let shared = LearningTracker()

    @Published private(set) var goals: [TrackedLearningGoal] = []

    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/LifeManagement", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            learnLogger.error("Failed to create storage directory: \(error.localizedDescription)")
        }
        storageURL = dir.appendingPathComponent("learning.json")
        loadState()
    }

    // MARK: - CRUD

    func addGoal(_ goal: TrackedLearningGoal) {
        goals.append(goal)
        save()
        learnLogger.info("Added learning goal: \(goal.title)")
    }

    // periphery:ignore - Reserved: updateGoal(_:) instance method — reserved for future feature activation
    func updateGoal(_ goal: TrackedLearningGoal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            var updated = goal
            // periphery:ignore - Reserved: updateGoal(_:) instance method reserved for future feature activation
            updated.updatedAt = Date()
            goals[idx] = updated
            save()
        }
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        save()
    }

    // periphery:ignore - Reserved: addStudySession(goalID:session:) instance method — reserved for future feature activation
    func addStudySession(goalID: UUID, session: StudySession) {
        if let idx = goals.firstIndex(where: { $0.id == goalID }) {
            // periphery:ignore - Reserved: addStudySession(goalID:session:) instance method reserved for future feature activation
            goals[idx].studySessions.append(session)
            goals[idx].updatedAt = Date()
            if goals[idx].status == .notStarted {
                goals[idx].status = .inProgress
            }
            save()
        }
    }

    // periphery:ignore - Reserved: addResource(goalID:resource:) instance method — reserved for future feature activation
    func addResource(goalID: UUID, resource: TrackedLearningResource) {
        // periphery:ignore - Reserved: addResource(goalID:resource:) instance method reserved for future feature activation
        if let idx = goals.firstIndex(where: { $0.id == goalID }) {
            goals[idx].resources.append(resource)
            goals[idx].updatedAt = Date()
            save()
        }
    }

    // MARK: - Analytics

    var activeGoals: [TrackedLearningGoal] {
        goals.filter { $0.status == .inProgress || $0.status == .notStarted }
            .sorted { $0.priority > $1.priority }
    }

    var completedGoals: [TrackedLearningGoal] {
        goals.filter { $0.status == .completed }
    }

    var totalStudyHours: Double {
        goals.reduce(0) { $0 + $1.totalStudyHours }
    }

    var longestStreak: Int {
        goals.map(\.currentStreak).max() ?? 0
    }

    // periphery:ignore - Reserved: goalsByCategory property reserved for future feature activation
    var goalsByCategory: [LearningCategory: [TrackedLearningGoal]] {
        Dictionary(grouping: goals, by: \.category)
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(goals)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            learnLogger.error("Failed to save learning data: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            learnLogger.error("Failed to read learning data: \(error.localizedDescription)")
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            goals = try decoder.decode([TrackedLearningGoal].self, from: data)
        } catch {
            learnLogger.error("Failed to decode learning data: \(error.localizedDescription)")
        }
    }
}
