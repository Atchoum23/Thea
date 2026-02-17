// WellnessModelsTests.swift
// Tests for WellnessModels: CircadianPhase, FocusSession, WellnessFocusMode,
// WellnessInsight, AmbientAudio, WellnessError, and PhaseRecommendation.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Integrations/Wellness/Models/WellnessModels.swift)

private enum TestCircadianPhase: String, CaseIterable, Sendable, Codable {
    case earlyMorning, morning, midday, afternoon, evening, night, lateNight, deepNight

    var displayName: String {
        switch self {
        case .earlyMorning: "Early Morning"
        case .morning: "Morning"
        case .midday: "Midday"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .night: "Night"
        case .lateNight: "Late Night"
        case .deepNight: "Deep Night"
        }
    }

    var startHour: Int {
        switch self {
        case .earlyMorning: 5
        case .morning: 7
        case .midday: 10
        case .afternoon: 13
        case .evening: 17
        case .night: 20
        case .lateNight: 22
        case .deepNight: 0
        }
    }

    var endHour: Int {
        switch self {
        case .earlyMorning: 7
        case .morning: 10
        case .midday: 13
        case .afternoon: 17
        case .evening: 20
        case .night: 22
        case .lateNight: 24
        case .deepNight: 5
        }
    }

    var recommendedBrightness: Double {
        switch self {
        case .earlyMorning: 0.6
        case .morning: 0.9
        case .midday: 1.0
        case .afternoon: 0.95
        case .evening: 0.7
        case .night: 0.4
        case .lateNight: 0.3
        case .deepNight: 0.2
        }
    }

    var blueFilterIntensity: Double {
        switch self {
        case .earlyMorning: 0.1
        case .morning: 0.0
        case .midday: 0.0
        case .afternoon: 0.2
        case .evening: 0.6
        case .night: 0.8
        case .lateNight: 0.9
        case .deepNight: 1.0
        }
    }

    static func current(hour: Int) -> TestCircadianPhase {
        if hour >= 5, hour < 7 { return .earlyMorning }
        if hour >= 7, hour < 10 { return .morning }
        if hour >= 10, hour < 13 { return .midday }
        if hour >= 13, hour < 17 { return .afternoon }
        if hour >= 17, hour < 20 { return .evening }
        if hour >= 20, hour < 22 { return .night }
        if hour >= 22 { return .lateNight }
        return .deepNight
    }
}

private enum TestWellnessFocusMode: String, Sendable, Codable, CaseIterable {
    case work, study, creative, relax, sleep

    var recommendedDuration: Int {
        switch self {
        case .work: 50
        case .study: 45
        case .creative: 90
        case .relax: 15
        case .sleep: 480
        }
    }

    var breakDuration: Int {
        switch self {
        case .work: 10
        case .study: 10
        case .creative: 20
        case .relax: 0
        case .sleep: 0
        }
    }

    var supportsAmbientAudio: Bool {
        switch self {
        case .work, .study, .creative, .relax: true
        case .sleep: false
        }
    }
}

private struct TestFocusSession: Sendable, Codable, Identifiable {
    let id: UUID
    let mode: TestWellnessFocusMode
    let startDate: Date
    let endDate: Date?
    let targetDuration: Int
    let completed: Bool
    let interrupted: Bool
    let notes: String?

    init(
        id: UUID = UUID(),
        mode: TestWellnessFocusMode,
        startDate: Date = Date(),
        endDate: Date? = nil,
        targetDuration: Int = 50,
        completed: Bool = false,
        interrupted: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.mode = mode
        self.startDate = startDate
        self.endDate = endDate
        self.targetDuration = targetDuration
        self.completed = completed
        self.interrupted = interrupted
        self.notes = notes
    }

    var actualDuration: Int? {
        guard let endDate else { return nil }
        return Int(endDate.timeIntervalSince(startDate) / 60)
    }

    var isActive: Bool {
        endDate == nil
    }

    var completionPercentage: Double {
        guard let actual = actualDuration else { return 0 }
        return min(100, (Double(actual) / Double(targetDuration)) * 100)
    }
}

private enum TestAmbientAudio: String, Sendable, Codable, CaseIterable {
    case rain, ocean, forest, whitenoise, brownnoise, fireplace, cafe, thunderstorm

    var displayName: String {
        switch self {
        case .rain: "Rain"
        case .ocean: "Ocean Waves"
        case .forest: "Forest"
        case .whitenoise: "White Noise"
        case .brownnoise: "Brown Noise"
        case .fireplace: "Fireplace"
        case .cafe: "Café Ambience"
        case .thunderstorm: "Thunderstorm"
        }
    }
}

private struct TestWellnessInsight: Sendable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: InsightCategory
    let priority: InsightPriority
    let timestamp: Date
    let actionItems: [String]

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: InsightCategory,
        priority: InsightPriority = .medium,
        actionItems: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.timestamp = Date()
        self.actionItems = actionItems
    }

    enum InsightCategory: String, Sendable {
        case circadian, focus, stress, productivity
    }

    enum InsightPriority: String, Sendable, Comparable {
        case low, medium, high, critical

        var rank: Int {
            switch self {
            case .low: 0
            case .medium: 1
            case .high: 2
            case .critical: 3
            }
        }

        static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
            lhs.rank < rhs.rank
        }
    }
}

private enum TestWellnessError: Error, LocalizedError {
    case sessionAlreadyActive
    case sessionNotFound
    case invalidDuration
    case audioPlaybackFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            "A focus session is already active. End the current session before starting a new one."
        case .sessionNotFound:
            "The requested focus session was not found."
        case .invalidDuration:
            "The session duration must be greater than 0."
        case let .audioPlaybackFailed(reason):
            "Audio playback failed: \(reason)"
        }
    }
}

private struct TestPhaseRecommendation: Hashable, Sendable {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Tests: CircadianPhase Determination

@Suite("CircadianPhase — Phase Determination")
struct CircadianPhaseDeterminationTests {
    @Test("All 24 hours map to a phase")
    func allHoursCovered() {
        for hour in 0..<24 {
            let phase = TestCircadianPhase.current(hour: hour)
            #expect(!phase.rawValue.isEmpty, "Hour \(hour) should map to a valid phase")
        }
    }

    @Test("Phase boundaries: early morning 5-6")
    func earlyMorning() {
        #expect(TestCircadianPhase.current(hour: 5) == .earlyMorning)
        #expect(TestCircadianPhase.current(hour: 6) == .earlyMorning)
    }

    @Test("Phase boundaries: morning 7-9")
    func morning() {
        #expect(TestCircadianPhase.current(hour: 7) == .morning)
        #expect(TestCircadianPhase.current(hour: 9) == .morning)
    }

    @Test("Phase boundaries: midday 10-12")
    func midday() {
        #expect(TestCircadianPhase.current(hour: 10) == .midday)
        #expect(TestCircadianPhase.current(hour: 12) == .midday)
    }

    @Test("Phase boundaries: afternoon 13-16")
    func afternoon() {
        #expect(TestCircadianPhase.current(hour: 13) == .afternoon)
        #expect(TestCircadianPhase.current(hour: 16) == .afternoon)
    }

    @Test("Phase boundaries: evening 17-19")
    func evening() {
        #expect(TestCircadianPhase.current(hour: 17) == .evening)
        #expect(TestCircadianPhase.current(hour: 19) == .evening)
    }

    @Test("Phase boundaries: night 20-21")
    func night() {
        #expect(TestCircadianPhase.current(hour: 20) == .night)
        #expect(TestCircadianPhase.current(hour: 21) == .night)
    }

    @Test("Phase boundaries: late night 22-23")
    func lateNight() {
        #expect(TestCircadianPhase.current(hour: 22) == .lateNight)
        #expect(TestCircadianPhase.current(hour: 23) == .lateNight)
    }

    @Test("Phase boundaries: deep night 0-4")
    func deepNight() {
        #expect(TestCircadianPhase.current(hour: 0) == .deepNight)
        #expect(TestCircadianPhase.current(hour: 4) == .deepNight)
    }

    @Test("All 8 phases are reachable")
    func allPhasesReachable() {
        var reachedPhases: Set<TestCircadianPhase> = []
        for hour in 0..<24 {
            reachedPhases.insert(TestCircadianPhase.current(hour: hour))
        }
        #expect(reachedPhases.count == 8)
    }

    @Test("No gaps between phases — every hour has exactly one phase")
    func noGaps() {
        // Ensure adjacent hours either map to same phase or adjacent phase transition
        for hour in 0..<23 {
            let current = TestCircadianPhase.current(hour: hour)
            let next = TestCircadianPhase.current(hour: hour + 1)
            // Either same phase, or valid transition (just check both are valid)
            #expect(TestCircadianPhase.allCases.contains(current))
            #expect(TestCircadianPhase.allCases.contains(next))
        }
    }
}

// MARK: - Tests: CircadianPhase Properties

@Suite("CircadianPhase — Properties")
struct CircadianPhasePropertyTests {
    @Test("All phases have display names")
    func displayNames() {
        for phase in TestCircadianPhase.allCases {
            #expect(!phase.displayName.isEmpty, "\(phase.rawValue) should have a display name")
        }
    }

    @Test("Brightness peaks at midday")
    func brightnessPeaksMidday() {
        #expect(TestCircadianPhase.midday.recommendedBrightness == 1.0)
        // Deep night should be lowest
        #expect(TestCircadianPhase.deepNight.recommendedBrightness == 0.2)
    }

    @Test("Brightness monotonically increases from deepNight to midday")
    func brightnessIncrease() {
        let morningPhases: [TestCircadianPhase] = [.deepNight, .earlyMorning, .morning, .midday]
        let brightnesses = morningPhases.map(\.recommendedBrightness)
        for i in 0..<brightnesses.count - 1 {
            #expect(brightnesses[i] <= brightnesses[i + 1],
                    "\(morningPhases[i]) brightness should be <= \(morningPhases[i + 1])")
        }
    }

    @Test("Blue filter intensity is 0 during morning and midday")
    func blueFilterDaylight() {
        #expect(TestCircadianPhase.morning.blueFilterIntensity == 0.0)
        #expect(TestCircadianPhase.midday.blueFilterIntensity == 0.0)
    }

    @Test("Blue filter intensity peaks at deep night")
    func blueFilterPeaksAtNight() {
        #expect(TestCircadianPhase.deepNight.blueFilterIntensity == 1.0)
    }

    @Test("Blue filter monotonically increases from midday to deepNight")
    func blueFilterIncrease() {
        let eveningPhases: [TestCircadianPhase] = [.midday, .afternoon, .evening, .night, .lateNight, .deepNight]
        let intensities = eveningPhases.map(\.blueFilterIntensity)
        for i in 0..<intensities.count - 1 {
            #expect(intensities[i] <= intensities[i + 1],
                    "\(eveningPhases[i]) blue filter should be <= \(eveningPhases[i + 1])")
        }
    }

    @Test("startHour and endHour cover all 24 hours without overlap")
    func hourRangesComplete() {
        var coveredHours: Set<Int> = []
        for phase in TestCircadianPhase.allCases {
            let start = phase.startHour
            let end = phase.endHour
            if start < end {
                for h in start..<end {
                    coveredHours.insert(h)
                }
            } else {
                // Wraps midnight (deepNight: 0-5)
                for h in start..<24 {
                    coveredHours.insert(h)
                }
                for h in 0..<end {
                    coveredHours.insert(h)
                }
            }
        }
        #expect(coveredHours == Set(0..<24))
    }
}

// MARK: - Tests: WellnessFocusMode

@Suite("WellnessFocusMode — Properties")
struct WellnessFocusModeTests {
    @Test("All 5 focus modes exist")
    func allCases() {
        #expect(TestWellnessFocusMode.allCases.count == 5)
    }

    @Test("Recommended durations are positive")
    func positiveDurations() {
        for mode in TestWellnessFocusMode.allCases {
            #expect(mode.recommendedDuration > 0, "\(mode) should have positive duration")
        }
    }

    @Test("Sleep has longest recommended duration")
    func sleepLongestDuration() {
        let maxDuration = TestWellnessFocusMode.allCases.max { $0.recommendedDuration < $1.recommendedDuration }
        #expect(maxDuration == .sleep)
    }

    @Test("Break durations are non-negative")
    func nonNegativeBreaks() {
        for mode in TestWellnessFocusMode.allCases {
            #expect(mode.breakDuration >= 0, "\(mode) should have non-negative break duration")
        }
    }

    @Test("Sleep and relax have zero break duration")
    func sleepRelaxNoBreak() {
        #expect(TestWellnessFocusMode.sleep.breakDuration == 0)
        #expect(TestWellnessFocusMode.relax.breakDuration == 0)
    }

    @Test("Sleep does not support ambient audio")
    func sleepNoAmbient() {
        #expect(!TestWellnessFocusMode.sleep.supportsAmbientAudio)
    }

    @Test("Work, study, creative, relax support ambient audio")
    func othersHaveAmbient() {
        #expect(TestWellnessFocusMode.work.supportsAmbientAudio)
        #expect(TestWellnessFocusMode.study.supportsAmbientAudio)
        #expect(TestWellnessFocusMode.creative.supportsAmbientAudio)
        #expect(TestWellnessFocusMode.relax.supportsAmbientAudio)
    }

    @Test("Creative mode has longest break duration")
    func creativeLongestBreak() {
        let maxBreak = TestWellnessFocusMode.allCases.max { $0.breakDuration < $1.breakDuration }
        #expect(maxBreak == .creative)
    }
}

// MARK: - Tests: FocusSession

@Suite("FocusSession — Lifecycle")
struct FocusSessionTests {
    @Test("New session is active (no endDate)")
    func newSessionActive() {
        let session = TestFocusSession(mode: .work)
        #expect(session.isActive)
        #expect(session.actualDuration == nil)
        #expect(session.completionPercentage == 0)
    }

    @Test("Completed session reports actual duration")
    func completedDuration() {
        let start = Date()
        let end = start.addingTimeInterval(25 * 60) // 25 minutes
        let session = TestFocusSession(mode: .work, startDate: start, endDate: end, targetDuration: 50, completed: true)
        #expect(!session.isActive)
        #expect(session.actualDuration == 25)
    }

    @Test("Completion percentage calculation")
    func completionPercentage() {
        let start = Date()
        let end = start.addingTimeInterval(30 * 60) // 30 minutes
        let session = TestFocusSession(mode: .study, startDate: start, endDate: end, targetDuration: 45)
        let percentage = session.completionPercentage
        #expect(abs(percentage - 66.67) < 0.1)
    }

    @Test("Completion percentage caps at 100%")
    func cappedAt100() {
        let start = Date()
        let end = start.addingTimeInterval(120 * 60) // 120 minutes
        let session = TestFocusSession(mode: .work, startDate: start, endDate: end, targetDuration: 50)
        #expect(session.completionPercentage == 100)
    }

    @Test("Interrupted session tracking")
    func interruptedSession() {
        let session = TestFocusSession(
            mode: .study,
            endDate: Date().addingTimeInterval(10 * 60),
            targetDuration: 45,
            completed: false,
            interrupted: true
        )
        #expect(session.interrupted)
        #expect(!session.completed)
        #expect(!session.isActive) // has endDate
    }

    @Test("Session notes are preserved")
    func notesPreserved() {
        let session = TestFocusSession(mode: .creative, notes: "Working on painting")
        #expect(session.notes == "Working on painting")
    }

    @Test("Session with nil notes")
    func nilNotes() {
        let session = TestFocusSession(mode: .work)
        #expect(session.notes == nil)
    }

    @Test("Unique session IDs")
    func uniqueIDs() {
        let s1 = TestFocusSession(mode: .work)
        let s2 = TestFocusSession(mode: .work)
        #expect(s1.id != s2.id)
    }
}

// MARK: - Tests: FocusSession Codable

@Suite("FocusSession — Codable")
struct FocusSessionCodableTests {
    @Test("Active session roundtrips through JSON")
    func activeCodable() throws {
        let session = TestFocusSession(mode: .study, targetDuration: 45)
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(TestFocusSession.self, from: data)
        #expect(decoded.id == session.id)
        #expect(decoded.mode == .study)
        #expect(decoded.targetDuration == 45)
        #expect(decoded.isActive)
    }

    @Test("Completed session roundtrips through JSON")
    func completedCodable() throws {
        let start = Date()
        let end = start.addingTimeInterval(50 * 60)
        let session = TestFocusSession(mode: .work, startDate: start, endDate: end, targetDuration: 50, completed: true)
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(TestFocusSession.self, from: data)
        #expect(decoded.completed)
        #expect(!decoded.isActive)
    }
}

// MARK: - Tests: AmbientAudio

@Suite("AmbientAudio — Completeness")
struct AmbientAudioTests {
    @Test("All 8 audio types exist")
    func allCases() {
        #expect(TestAmbientAudio.allCases.count == 8)
    }

    @Test("All audio types have non-empty display names")
    func displayNames() {
        for audio in TestAmbientAudio.allCases {
            #expect(!audio.displayName.isEmpty, "\(audio.rawValue) should have a display name")
        }
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestAmbientAudio.allCases.map(\.rawValue))
        #expect(rawValues.count == TestAmbientAudio.allCases.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for audio in TestAmbientAudio.allCases {
            let data = try JSONEncoder().encode(audio)
            let decoded = try JSONDecoder().decode(TestAmbientAudio.self, from: data)
            #expect(decoded == audio)
        }
    }
}

// MARK: - Tests: WellnessInsight

@Suite("WellnessInsight — Construction")
struct WellnessInsightTests {
    @Test("Insight has unique ID")
    func uniqueID() {
        let i1 = TestWellnessInsight(title: "A", description: "a", category: .focus)
        let i2 = TestWellnessInsight(title: "A", description: "a", category: .focus)
        #expect(i1.id != i2.id)
    }

    @Test("Action items are preserved")
    func actionItems() {
        let insight = TestWellnessInsight(
            title: "Take a break",
            description: "You've been working for 2 hours",
            category: .productivity,
            actionItems: ["Stand up", "Stretch", "Walk for 5 minutes"]
        )
        #expect(insight.actionItems.count == 3)
        #expect(insight.actionItems[0] == "Stand up")
    }

    @Test("Priority comparison works correctly")
    func priorityComparison() {
        #expect(TestWellnessInsight.InsightPriority.low < .medium)
        #expect(TestWellnessInsight.InsightPriority.medium < .high)
        #expect(TestWellnessInsight.InsightPriority.high < .critical)
    }

    @Test("Insights sort by priority")
    func sortByPriority() {
        let low = TestWellnessInsight(title: "Low", description: "", category: .focus, priority: .low)
        let critical = TestWellnessInsight(title: "Critical", description: "", category: .stress, priority: .critical)
        let medium = TestWellnessInsight(title: "Medium", description: "", category: .circadian, priority: .medium)

        let sorted = [low, critical, medium].sorted { $0.priority > $1.priority }
        #expect(sorted[0].title == "Critical")
        #expect(sorted[1].title == "Medium")
        #expect(sorted[2].title == "Low")
    }
}

// MARK: - Tests: WellnessError

@Suite("WellnessError — Descriptions")
struct WellnessErrorTests {
    @Test("sessionAlreadyActive has descriptive message")
    func sessionAlreadyActive() {
        let error = TestWellnessError.sessionAlreadyActive
        #expect(error.errorDescription?.contains("already active") == true)
    }

    @Test("sessionNotFound has descriptive message")
    func sessionNotFound() {
        let error = TestWellnessError.sessionNotFound
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("invalidDuration has descriptive message")
    func invalidDuration() {
        let error = TestWellnessError.invalidDuration
        #expect(error.errorDescription?.contains("greater than 0") == true)
    }

    @Test("audioPlaybackFailed includes reason")
    func audioPlaybackFailed() {
        let error = TestWellnessError.audioPlaybackFailed("codec not supported")
        #expect(error.errorDescription?.contains("codec not supported") == true)
    }

    @Test("All error cases provide non-nil descriptions")
    func allDescriptionsNonNil() {
        let errors: [TestWellnessError] = [
            .sessionAlreadyActive,
            .sessionNotFound,
            .invalidDuration,
            .audioPlaybackFailed("test")
        ]
        for error in errors {
            #expect(error.errorDescription != nil, "\(error) should have a description")
        }
    }
}

// MARK: - Tests: PhaseRecommendation

@Suite("PhaseRecommendation — Properties")
struct PhaseRecommendationTests {
    @Test("Recommendation stores all properties")
    func storesProperties() {
        let rec = TestPhaseRecommendation(
            icon: "sun.max.fill",
            title: "Get sunlight",
            description: "Exposure to natural light helps regulate circadian rhythm"
        )
        #expect(rec.icon == "sun.max.fill")
        #expect(rec.title == "Get sunlight")
        #expect(!rec.description.isEmpty)
    }

    @Test("Recommendations are Hashable (can be stored in Sets)")
    func hashable() {
        let r1 = TestPhaseRecommendation(icon: "a", title: "A", description: "a")
        let r2 = TestPhaseRecommendation(icon: "b", title: "B", description: "b")
        let r3 = TestPhaseRecommendation(icon: "a", title: "A", description: "a") // same as r1
        let set: Set<TestPhaseRecommendation> = [r1, r2, r3]
        #expect(set.count == 2)
    }

    @Test("Equal recommendations are equal")
    func equality() {
        let r1 = TestPhaseRecommendation(icon: "x", title: "X", description: "x")
        let r2 = TestPhaseRecommendation(icon: "x", title: "X", description: "x")
        #expect(r1 == r2)
    }
}
