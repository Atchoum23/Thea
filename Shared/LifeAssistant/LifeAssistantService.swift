// LifeAssistantService.swift
// Thea V2
//
// 24/7 AI-powered life assistance service.
// Proactively helps with all aspects of daily life.
//
// CAPABILITIES:
// - Proactive reminders and suggestions
// - Context-aware assistance based on time, location, calendar
// - Health and wellness monitoring
// - Financial awareness
// - Relationship and social insights
// - Learning and growth recommendations
// - Work-life balance optimization
//
// CREATED: February 2, 2026

import Foundation
import OSLog
import EventKit
#if canImport(HealthKit)
import HealthKit
#endif
import CoreLocation
import UserNotifications
#if os(macOS)
import AppKit
#endif

// MARK: - Life Assistant Service

@MainActor
@Observable
public final class LifeAssistantService {
    public static let shared = LifeAssistantService()

    private let logger = Logger(subsystem: "com.thea.life", category: "LifeAssistant")

    // MARK: - Services

    private let calendarService = CalendarAssistant()
    private let healthService = HealthAssistant()
    private let financialService = FinancialAssistant()
    private let socialService = SocialAssistant()
    private let productivityService = ProductivityAssistant()
    private let learningService = LearningAssistant()

    // MARK: - Configuration

    public var isEnabled: Bool = true {
        didSet { saveSettings() }
    }

    public var proactiveMode: Bool = true {
        didSet { saveSettings() }
    }

    public var quietHoursStart: Int = 22 // 10 PM
    public var quietHoursEnd: Int = 7    // 7 AM

    // MARK: - State

    public private(set) var currentContext = AssistantContext()
    public private(set) var dailyBriefing: DailyBriefing?
    public private(set) var activeInsights: [AssistantInsight] = []
    public private(set) var pendingActions: [LifeSuggestedAction] = []

    // MARK: - Dynamic Configuration
    // Note: Uses DynamicConfig for AI-powered optimal values instead of hardcoded constants

    private var updateTimer: Timer?

    private init() {
        loadSettings()
        startMonitoring()
    }

    // Note: Timer cleanup handled via stopMonitoring() since deinit can't access @MainActor state
    // Call stopMonitoring() before releasing this service

    // MARK: - Public API

    /// Get a comprehensive daily briefing
    public func generateDailyBriefing() async -> DailyBriefing {
        logger.info("Generating daily briefing...")

        let calendar = await calendarService.getTodayOverview()
        let health = await healthService.getDailyMetrics()
        let tasks = await productivityService.getPriorityTasks()
        let weather = await getWeatherForecast()
        let insights = await generateDailyInsights()

        let briefing = DailyBriefing(
            date: Date(),
            greeting: generateGreeting(),
            calendarSummary: calendar,
            healthSummary: health,
            priorityTasks: tasks,
            weatherForecast: weather,
            insights: insights,
            motivationalQuote: await getMotivationalQuote()
        )

        dailyBriefing = briefing
        return briefing
    }

    /// Get contextual suggestions based on current situation
    public func getContextualSuggestions() async -> [LifeSuggestedAction] {
        var suggestions: [LifeSuggestedAction] = []

        // Time-based suggestions
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 6 && hour <= 9 {
            // Morning routine suggestions
            if let health = await healthService.getDailyMetrics() {
                if health.sleepHours < 7 {
                    suggestions.append(LifeSuggestedAction(
                        type: .health,
                        title: "Consider earlier bedtime",
                        description: "You got \(String(format: "%.1f", health.sleepHours)) hours of sleep. Aim for 7-8 hours.",
                        priority: .medium
                    )                        { /* Open sleep settings */ })
                }
            }
        } else if hour >= 12 && hour <= 13 {
            // Lunch time suggestions
            suggestions.append(LifeSuggestedAction(
                type: .health,
                title: "Lunch break reminder",
                description: "Take a break to eat and recharge. Step away from screens.",
                priority: .low,
                action: nil
            ))
        } else if hour >= 17 && hour <= 19 {
            // End of work day
            let unfinished = await productivityService.getUnfinishedTasks()
            if !unfinished.isEmpty {
                suggestions.append(LifeSuggestedAction(
                    type: .productivity,
                    title: "Wrap up \(unfinished.count) tasks",
                    description: "Consider finishing or rescheduling: \(unfinished.first ?? "")",
                    priority: .medium,
                    action: nil
                ))
            }
        }

        // Calendar-based suggestions
        let upcoming = await calendarService.getUpcomingEvents(hours: 2)
        for event in upcoming {
            let timeUntil = event.startDate.timeIntervalSinceNow / 60
            if timeUntil > 0 && timeUntil <= 30 {
                suggestions.append(LifeSuggestedAction(
                    type: .calendar,
                    title: "Upcoming: \(event.title)",
                    description: "Starts in \(Int(timeUntil)) minutes",
                    priority: .high,
                    action: nil
                ))
            }
        }

        // Financial suggestions (weekly)
        if Calendar.current.component(.weekday, from: Date()) == 1 { // Sunday
            if let financial = await financialService.getWeeklySummary() {
                if financial.spending > financial.budget * 0.8 {
                    suggestions.append(LifeSuggestedAction(
                        type: .financial,
                        title: "Budget alert",
                        description: "You've spent \(Int(financial.spending / financial.budget * 100))% of your weekly budget",
                        priority: .medium,
                        action: nil
                    ))
                }
            }
        }

        pendingActions = suggestions
        return suggestions
    }

    /// Process a life-related query
    public func processQuery(_ query: String) async -> AssistantResponse {
        let category = categorizeQuery(query)

        switch category {
        case .calendar:
            return await calendarService.processQuery(query)
        case .health:
            return await healthService.processQuery(query)
        case .financial:
            return await financialService.processQuery(query)
        case .social:
            return await socialService.processQuery(query)
        case .productivity:
            return await productivityService.processQuery(query)
        case .learning:
            return await learningService.processQuery(query)
        case .general:
            return await processGeneralQuery(query)
        }
    }

    /// Schedule a proactive check-in
    public func scheduleCheckIn(at date: Date, type: CheckInType) {
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.hour, .minute], from: date),
            repeats: type.repeats
        )

        let request = UNNotificationRequest(
            identifier: "thea.checkin.\(type.rawValue)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        // Update context periodically using dynamic interval
        Task {
            let interval = await DynamicConfig.shared.interval(for: .contextUpdate)
            await MainActor.run {
                updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.updateContext()
                    }
                }
            }
            await updateContext()
        }
    }

    /// Stop monitoring (call when service should be paused)
    public func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateContext() async {
        let hour = Calendar.current.component(.hour, from: Date())
        let isQuietHours = hour >= quietHoursStart || hour < quietHoursEnd

        var focusApp: String?
        #if os(macOS)
        focusApp = NSWorkspace.shared.frontmostApplication?.localizedName
        #endif

        currentContext = AssistantContext(
            timeOfDay: getTimeOfDay(),
            dayOfWeek: getDayOfWeek(),
            isWorkHours: hour >= 9 && hour <= 17,
            isQuietHours: isQuietHours,
            upcomingEvents: await calendarService.getUpcomingEvents(hours: 4),
            currentActivity: detectCurrentActivity(),
            energyLevel: await healthService.estimateEnergyLevel(),
            focusMode: focusApp
        )

        // Generate insights if not in quiet hours and proactive mode is on
        if proactiveMode && !isQuietHours {
            activeInsights = await generateActiveInsights()
        }
    }

    private func generateGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = "there" // Could personalize with user's name

        if hour < 12 {
            return "Good morning, \(name)!"
        } else if hour < 17 {
            return "Good afternoon, \(name)!"
        } else {
            return "Good evening, \(name)!"
        }
    }

    private func getTimeOfDay() -> AssistantTimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    private func getDayOfWeek() -> AssistantDayType {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday == 1 || weekday == 7) ? .weekend : .weekday
    }

    private func detectCurrentActivity() -> AssistantActivity {
        #if os(macOS)
        // Detect based on active app, time, etc.
        guard let app = NSWorkspace.shared.frontmostApplication?.localizedName else {
            return .idle
        }

        let codingApps = ["Xcode", "VS Code", "Terminal", "iTerm"]
        let communicationApps = ["Mail", "Slack", "Messages", "Discord"]
        let browserApps = ["Safari", "Chrome", "Firefox"]

        if codingApps.contains(app) {
            return .coding
        } else if communicationApps.contains(app) {
            return .communicating
        } else if browserApps.contains(app) {
            return .browsing
        } else {
            return .other(app)
        }
        #else
        return .idle
        #endif
    }

    private func generateDailyInsights() async -> [AssistantInsight] {
        var insights: [AssistantInsight] = []

        // Productivity insight
        let productivity = await productivityService.getProductivityScore()
        if productivity < 0.5 {
            insights.append(AssistantInsight(
                category: .productivity,
                title: "Productivity Opportunity",
                message: "Your productivity has been lower than usual. Consider breaking tasks into smaller chunks.",
                actionable: true
            ))
        }

        // Health insight
        if let health = await healthService.getDailyMetrics() {
            if health.steps < 5000 {
                insights.append(AssistantInsight(
                    category: .health,
                    title: "Movement Reminder",
                    message: "You're at \(health.steps) steps. A short walk could boost your energy and creativity.",
                    actionable: true
                ))
            }
        }

        // Learning insight (weekly)
        if Calendar.current.component(.weekday, from: Date()) == 1 {
            let learning = await learningService.getWeeklyProgress()
            if learning.hoursLearned < learning.goal {
                insights.append(AssistantInsight(
                    category: .learning,
                    title: "Learning Goal",
                    message: "You learned \(String(format: "%.1f", learning.hoursLearned)) hours this week. Your goal is \(String(format: "%.1f", learning.goal)) hours.",
                    actionable: true
                ))
            }
        }

        return insights
    }

    private func generateActiveInsights() async -> [AssistantInsight] {
        // Real-time insights based on current context
        var insights: [AssistantInsight] = []

        // Focus time insight
        if currentContext.isWorkHours && currentContext.currentActivity == .coding {
            let focusTime = await productivityService.getCurrentFocusTime()
            if focusTime > 90 {
                insights.append(AssistantInsight(
                    category: .productivity,
                    title: "Break Time",
                    message: "You've been focused for \(Int(focusTime)) minutes. A 5-10 minute break can improve performance.",
                    actionable: true
                ))
            }
        }

        return insights
    }

    private func categorizeQuery(_ query: String) -> QueryCategory {
        let lowercased = query.lowercased()

        if lowercased.contains("meeting") || lowercased.contains("calendar") ||
           lowercased.contains("schedule") || lowercased.contains("appointment") {
            return .calendar
        } else if lowercased.contains("health") || lowercased.contains("sleep") ||
                  lowercased.contains("exercise") || lowercased.contains("steps") {
            return .health
        } else if lowercased.contains("budget") || lowercased.contains("money") ||
                  lowercased.contains("spend") || lowercased.contains("financial") {
            return .financial
        } else if lowercased.contains("friend") || lowercased.contains("family") ||
                  lowercased.contains("relationship") || lowercased.contains("social") {
            return .social
        } else if lowercased.contains("task") || lowercased.contains("todo") ||
                  lowercased.contains("productivity") || lowercased.contains("work") {
            return .productivity
        } else if lowercased.contains("learn") || lowercased.contains("study") ||
                  lowercased.contains("course") || lowercased.contains("skill") {
            return .learning
        }

        return .general
    }

    private func processGeneralQuery(_ query: String) async -> AssistantResponse {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return AssistantResponse(message: "No AI provider available", suggestions: [])
        }

        let contextPrompt = """
        You are a helpful life assistant. The user's current context:
        - Time: \(currentContext.timeOfDay.rawValue)
        - Day: \(currentContext.dayOfWeek.rawValue)
        - Activity: \(currentContext.currentActivity.description)

        Respond helpfully and concisely to their query.
        """

        do {
            let model = await DynamicConfig.shared.bestModel(for: .assistance)
            let fullPrompt = contextPrompt + "\n\nUser query: " + query
            let response = try await streamToString(provider: provider, prompt: fullPrompt, model: model)

            return AssistantResponse(message: response, suggestions: [])
        } catch {
            logger.warning("AI query failed: \(error.localizedDescription)")
            return AssistantResponse(message: "I couldn't process that request. Please try again.", suggestions: [])
        }
    }

    private func streamToString(provider: AIProvider, prompt: String, model: String) async throws -> String {
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: model
        )
        let stream = try await provider.chat(messages: [message], model: model, stream: false)
        var result = ""
        for try await response in stream {
            switch response.type {
            case .delta(let text):
                result += text
            case .complete(let msg):
                result = msg.content.textValue
            case .error(let error):
                throw error
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getWeatherForecast() async -> String? {
        // Would integrate with weather API
        "Partly cloudy, 72°F"
    }

    private func getMotivationalQuote() async -> String {
        let quotes = [
            "The only way to do great work is to love what you do. - Steve Jobs",
            "Success is not final, failure is not fatal: it is the courage to continue that counts. - Winston Churchill",
            "The future belongs to those who believe in the beauty of their dreams. - Eleanor Roosevelt",
            "It does not matter how slowly you go as long as you do not stop. - Confucius",
            "The best time to plant a tree was 20 years ago. The second best time is now. - Chinese Proverb"
        ]
        return quotes.randomElement() ?? quotes[0]
    }

    private func loadSettings() {
        isEnabled = UserDefaults.standard.object(forKey: "LifeAssistant.isEnabled") as? Bool ?? true
        proactiveMode = UserDefaults.standard.object(forKey: "LifeAssistant.proactiveMode") as? Bool ?? true
    }

    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "LifeAssistant.isEnabled")
        UserDefaults.standard.set(proactiveMode, forKey: "LifeAssistant.proactiveMode")
    }
}

// MARK: - Sub-Services (Wired to Real Data Sources)

@MainActor
final class CalendarAssistant {
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.thea.life", category: "CalendarAssistant")

    func getTodayOverview() async -> AssistantCalendarSummary? {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else {
            return nil
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let now = Date()
        let nextEvent = events.first(where: { $0.startDate > now })
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let nextEventStr = nextEvent.map { "\($0.title ?? "Event") at \(formatter.string(from: $0.startDate))" }

        // Estimate free time: total waking hours (16) minus scheduled hours
        let scheduledHours = events.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }
        let freeTime = max(0, Int(16 - scheduledHours))

        return AssistantCalendarSummary(eventCount: events.count, nextEvent: nextEventStr, freeTime: freeTime)
    }

    func getUpcomingEvents(hours: Int) async -> [AssistantCalendarEvent] {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else { return [] }
        let now = Date()
        let end = Calendar.current.date(byAdding: .hour, value: hours, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)
        return eventStore.events(matching: predicate).map { event in
            AssistantCalendarEvent(
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location
            )
        }
    }

    func processQuery(_ query: String) async -> AssistantResponse {
        let events = await getUpcomingEvents(hours: 24)
        if events.isEmpty {
            return AssistantResponse(message: "No upcoming events in the next 24 hours. Your schedule is clear!", suggestions: [])
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let eventList = events.prefix(5).map { "- \($0.title) at \(formatter.string(from: $0.startDate))" }.joined(separator: "\n")
        return AssistantResponse(
            message: "Here are your upcoming events:\n\(eventList)",
            suggestions: []
        )
    }
}

@MainActor
final class HealthAssistant {
    #if os(macOS) || os(iOS) || os(watchOS)
    private let healthStore = HKHealthStore()
    #endif
    private let logger = Logger(subsystem: "com.thea.life", category: "HealthAssistant")

    func getDailyMetrics() async -> AssistantHealthMetrics? {
        #if os(macOS) || os(iOS) || os(watchOS)
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let steps = await queryTodaySum(for: .stepCount)
        let activeCalories = await queryTodaySum(for: .activeEnergyBurned)
        let sleepHours = await querySleepHours()
        let heartRate = await queryLatestHeartRate()

        return AssistantHealthMetrics(
            steps: Int(steps),
            sleepHours: sleepHours,
            activeCalories: Int(activeCalories),
            heartRate: Int(heartRate)
        )
        #else
        return nil
        #endif
    }

    func estimateEnergyLevel() async -> Double {
        guard let metrics = await getDailyMetrics() else { return 0.5 }
        // Estimate energy based on sleep quality and activity
        let sleepScore = min(metrics.sleepHours / 8.0, 1.0)
        let activityScore = min(Double(metrics.steps) / 10000.0, 1.0)
        return (sleepScore * 0.6 + activityScore * 0.4)
    }

    func processQuery(_ query: String) async -> AssistantResponse {
        guard let metrics = await getDailyMetrics() else {
            return AssistantResponse(
                message: "Health data is not available. Please ensure HealthKit access is granted in Settings.",
                suggestions: []
            )
        }
        let msg = """
        Today's health summary:
        - Steps: \(metrics.steps)
        - Active calories: \(metrics.activeCalories) kcal
        - Sleep: \(String(format: "%.1f", metrics.sleepHours)) hours
        - Heart rate: \(metrics.heartRate) bpm
        """
        return AssistantResponse(message: msg, suggestions: [])
    }

    #if os(macOS) || os(iOS) || os(watchOS)
    private func queryTodaySum(for identifier: HKQuantityTypeIdentifier) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let unit: HKUnit = identifier == .stepCount ? .count() : .kilocalorie()
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func querySleepHours() async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let calendar = Calendar.current
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let totalSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                } ?? 0
                continuation.resume(returning: totalSeconds / 3600)
            }
            healthStore.execute(query)
        }
    }

    private func queryLatestHeartRate() async -> Double {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }
    #endif
}

@MainActor
final class FinancialAssistant {
    private let logger = Logger(subsystem: "com.thea.life", category: "FinancialAssistant")

    func getWeeklySummary() async -> AssistantFinancialSummary? {
        // Read from UserDefaults-persisted financial data (set by FinancialDataManager)
        let weeklySpending = UserDefaults.standard.double(forKey: "finance.weeklySpending")
        let weeklyBudget = UserDefaults.standard.double(forKey: "finance.weeklyBudget")
        if weeklyBudget > 0 {
            return AssistantFinancialSummary(
                spending: weeklySpending,
                budget: weeklyBudget,
                savings: max(0, weeklyBudget - weeklySpending)
            )
        }
        return nil
    }

    func processQuery(_ query: String) async -> AssistantResponse {
        if let summary = await getWeeklySummary() {
            let pct = summary.budget > 0 ? Int((summary.spending / summary.budget) * 100) : 0
            return AssistantResponse(
                message: "This week: spent \(String(format: "%.0f", summary.spending)) of \(String(format: "%.0f", summary.budget)) budget (\(pct)%). Savings: \(String(format: "%.0f", summary.savings)).",
                suggestions: []
            )
        }
        return AssistantResponse(
            message: "No financial data available yet. Set up budget tracking in Financial settings to get insights.",
            suggestions: []
        )
    }
}

@MainActor
final class SocialAssistant {
    func processQuery(_ query: String) async -> AssistantResponse {
        // Query contacts and recent interactions from PersonalKnowledgeGraph
        let graph = PersonalKnowledgeGraph.shared
        let result = await graph.query(query)
        if result.entities.isEmpty {
            return AssistantResponse(
                message: "I don't have enough social context yet. As you interact with people through Thea, I'll build insights about your relationships and communication patterns.",
                suggestions: []
            )
        }
        let insights = result.entities.prefix(3).map { "- \($0.name): \($0.type.rawValue)" }.joined(separator: "\n")
        return AssistantResponse(message: "\(result.explanation)\n\(insights)", suggestions: [])
    }
}

@MainActor
final class ProductivityAssistant {
    private let logger = Logger(subsystem: "com.thea.life", category: "ProductivityAssistant")

    func getPriorityTasks() async -> [String] {
        // Read from UserDefaults-persisted task data
        UserDefaults.standard.stringArray(forKey: "productivity.priorityTasks") ?? []
    }

    func getUnfinishedTasks() async -> [String] {
        UserDefaults.standard.stringArray(forKey: "productivity.unfinishedTasks") ?? []
    }

    func getProductivityScore() async -> Double {
        // Calculate from actual focus time vs target
        let focusMinutes = await getCurrentFocusTime()
        let targetMinutes: Double = 240 // 4 hours target focus time
        return min(focusMinutes / targetMinutes, 1.0)
    }

    func getCurrentFocusTime() async -> TimeInterval {
        // Track focus time since last break (stored by activity logger)
        UserDefaults.standard.double(forKey: "productivity.focusMinutes")
    }

    func processQuery(_ query: String) async -> AssistantResponse {
        let tasks = await getPriorityTasks()
        let score = await getProductivityScore()
        let focusMinutes = Int(await getCurrentFocusTime())
        var msg = "Productivity score: \(Int(score * 100))% | Focus time today: \(focusMinutes) min"
        if !tasks.isEmpty {
            msg += "\n\nPriority tasks:\n" + tasks.prefix(5).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        }
        return AssistantResponse(message: msg, suggestions: [])
    }
}

@MainActor
final class LearningAssistant {
    func getWeeklyProgress() async -> AssistantLearningProgress {
        let hours = UserDefaults.standard.double(forKey: "learning.weeklyHours")
        let goal = UserDefaults.standard.double(forKey: "learning.weeklyGoal")
        let topics = UserDefaults.standard.stringArray(forKey: "learning.recentTopics") ?? []
        return AssistantLearningProgress(
            hoursLearned: hours,
            goal: goal > 0 ? goal : 5.0,
            topics: topics
        )
    }

    func processQuery(_ query: String) async -> AssistantResponse {
        let progress = await getWeeklyProgress()
        let pct = progress.goal > 0 ? Int((progress.hoursLearned / progress.goal) * 100) : 0
        var msg = "Learning progress: \(String(format: "%.1f", progress.hoursLearned))/\(String(format: "%.1f", progress.goal)) hours (\(pct)%)"
        if !progress.topics.isEmpty {
            msg += "\nRecent topics: " + progress.topics.joined(separator: ", ")
        }
        return AssistantResponse(message: msg, suggestions: [])
    }
}

// MARK: - Models
// Note: Types prefixed with "Assistant" to avoid conflicts with existing models

public struct AssistantContext: Sendable {
    public var timeOfDay: AssistantTimeOfDay = .morning
    public var dayOfWeek: AssistantDayType = .weekday
    public var isWorkHours: Bool = false
    public var isQuietHours: Bool = false
    public var upcomingEvents: [AssistantCalendarEvent] = []
    public var currentActivity: AssistantActivity = .idle
    public var energyLevel: Double = 0.5
    public var focusMode: String?
}

public enum AssistantTimeOfDay: String, Sendable {
    case morning, afternoon, evening, night
}

public enum AssistantDayType: String, Sendable {
    case weekday, weekend
}

public enum AssistantActivity: Sendable, Equatable {
    case idle, coding, communicating, browsing, other(String)

    var description: String {
        switch self {
        case .idle: return "idle"
        case .coding: return "coding"
        case .communicating: return "communicating"
        case .browsing: return "browsing"
        case .other(let app): return app
        }
    }
}

public struct DailyBriefing: Sendable {
    public let date: Date
    public let greeting: String
    public let calendarSummary: AssistantCalendarSummary?
    public let healthSummary: AssistantHealthMetrics?
    public let priorityTasks: [String]
    public let weatherForecast: String?
    public let insights: [AssistantInsight]
    public let motivationalQuote: String
}

public struct AssistantCalendarSummary: Sendable {
    public let eventCount: Int
    public let nextEvent: String?
    public let freeTime: Int // hours
}

public struct AssistantCalendarEvent: Sendable, Identifiable {
    public let id = UUID()
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
}

public struct AssistantHealthMetrics: Sendable {
    public let steps: Int
    public let sleepHours: Double
    public let activeCalories: Int
    public let heartRate: Int
}

public struct AssistantFinancialSummary: Sendable {
    public let spending: Double
    public let budget: Double
    public let savings: Double
}

public struct AssistantLearningProgress: Sendable {
    public let hoursLearned: Double
    public let goal: Double
    public let topics: [String]
}

public struct AssistantInsight: Sendable, Identifiable {
    public let id = UUID()
    public let category: AssistantInsightCategory
    public let title: String
    public let message: String
    public let actionable: Bool
}

public enum AssistantInsightCategory: String, Sendable {
    case productivity, health, financial, social, learning, general
}

public struct LifeSuggestedAction: Sendable, Identifiable {
    public let id = UUID()
    public let type: ActionType
    public let title: String
    public let description: String
    public let priority: ActionPriority
    public let action: (@Sendable () -> Void)?

    public enum ActionType: String, Sendable {
        case calendar, health, financial, productivity, social, learning
    }

    public enum ActionPriority: String, Sendable {
        case high, medium, low
    }
}

public struct AssistantResponse: Sendable {
    public let message: String
    public let suggestions: [LifeSuggestedAction]
}

public enum QueryCategory {
    case calendar, health, financial, social, productivity, learning, general
}

public enum CheckInType: String {
    case morning
    case midday
    case evening
    case weekly

    var title: String {
        switch self {
        case .morning: return "Good Morning!"
        case .midday: return "Midday Check-in"
        case .evening: return "Evening Reflection"
        case .weekly: return "Weekly Review"
        }
    }

    var body: String {
        switch self {
        case .morning: return "Ready to start your day? Let me give you a briefing."
        case .midday: return "How's your day going? Let's review your progress."
        case .evening: return "Time to wind down. Want to review what you accomplished?"
        case .weekly: return "Let's review your week and plan for the next one."
        }
    }

    var repeats: Bool {
        true
    }
}
