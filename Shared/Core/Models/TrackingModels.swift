import Foundation
@preconcurrency import SwiftData

// MARK: - Health Tracking Models

@Model
final class HealthSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var steps: Int
    var activeCalories: Double
    var heartRateAverage: Double?
    var heartRateMin: Double?
    var heartRateMax: Double?
    var sleepDuration: TimeInterval
    var workoutMinutes: Int
    var snapshotData: Data

    // periphery:ignore - Reserved: init(id:date:steps:activeCalories:heartRateAverage:heartRateMin:heartRateMax:sleepDuration:workoutMinutes:snapshotData:) initializer — reserved for future feature activation
    init(
        id: UUID = UUID(),
        date: Date,
        steps: Int = 0,
        activeCalories: Double = 0,
        heartRateAverage: Double? = nil,
        // periphery:ignore - Reserved: init(id:date:steps:activeCalories:heartRateAverage:heartRateMin:heartRateMax:sleepDuration:workoutMinutes:snapshotData:) initializer reserved for future feature activation
        heartRateMin: Double? = nil,
        heartRateMax: Double? = nil,
        sleepDuration: TimeInterval = 0,
        workoutMinutes: Int = 0,
        snapshotData: Data = Data()
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.activeCalories = activeCalories
        self.heartRateAverage = heartRateAverage
        self.heartRateMin = heartRateMin
        self.heartRateMax = heartRateMax
        self.sleepDuration = sleepDuration
        self.workoutMinutes = workoutMinutes
        self.snapshotData = snapshotData
    }
}

// MARK: - Screen Time Models

@Model
final class DailyScreenTimeRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalScreenTime: TimeInterval
    var appUsageData: Data
    var productivityScore: Double
    var focusTimeMinutes: Int

    // periphery:ignore - Reserved: init(id:date:totalScreenTime:appUsageData:productivityScore:focusTimeMinutes:) initializer — reserved for future feature activation
    init(
        id: UUID = UUID(),
        date: Date,
        totalScreenTime: TimeInterval = 0,
        appUsageData: Data = Data(),
        // periphery:ignore - Reserved: init(id:date:totalScreenTime:appUsageData:productivityScore:focusTimeMinutes:) initializer reserved for future feature activation
        productivityScore: Double = 0,
        focusTimeMinutes: Int = 0
    ) {
        self.id = id
        self.date = date
        self.totalScreenTime = totalScreenTime
        self.appUsageData = appUsageData
        self.productivityScore = productivityScore
        self.focusTimeMinutes = focusTimeMinutes
    }
}

// MARK: - Input Activity Models

@Model
final class DailyInputStatistics {
    @Attribute(.unique) var id: UUID
    var date: Date
    var mouseClicks: Int
    var keystrokes: Int
    var mouseDistancePixels: Double
    var activeMinutes: Int
    var activityLevel: String

    init(
        id: UUID = UUID(),
        date: Date,
        mouseClicks: Int = 0,
        // periphery:ignore - Reserved: init(id:date:mouseClicks:keystrokes:mouseDistancePixels:activeMinutes:activityLevel:) initializer reserved for future feature activation
        keystrokes: Int = 0,
        mouseDistancePixels: Double = 0,
        activeMinutes: Int = 0,
        activityLevel: String = "sedentary"
    ) {
        self.id = id
        self.date = date
        self.mouseClicks = mouseClicks
        self.keystrokes = keystrokes
        self.mouseDistancePixels = mouseDistancePixels
        self.activeMinutes = activeMinutes
        self.activityLevel = activityLevel
    }
}

// MARK: - Browsing History Models

@Model
final class BrowsingRecord {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var url: String
    var title: String
    var timestamp: Date
    var duration: TimeInterval
    var category: String
    var contentSummary: String?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        // periphery:ignore - Reserved: init(id:sessionID:url:title:timestamp:duration:category:contentSummary:) initializer reserved for future feature activation
        url: String,
        title: String,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        category: String = "other",
        contentSummary: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.url = url
        self.title = title
        self.timestamp = timestamp
        self.duration = duration
        self.category = category
        self.contentSummary = contentSummary
    }
}

// MARK: - Location Tracking Models

@Model
final class LocationVisitRecord {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var arrivalTime: Date
    var departureTime: Date?
    var placeName: String?
    var category: String

    // periphery:ignore - Reserved: init(id:latitude:longitude:arrivalTime:departureTime:placeName:category:) initializer — reserved for future feature activation
    init(
        id: UUID = UUID(),
        // periphery:ignore - Reserved: init(id:latitude:longitude:arrivalTime:departureTime:placeName:category:) initializer reserved for future feature activation
        latitude: Double,
        longitude: Double,
        arrivalTime: Date = Date(),
        departureTime: Date? = nil,
        placeName: String? = nil,
        category: String = "other"
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.placeName = placeName
        self.category = category
    }
}

// MARK: - AI Insights Models

@Model
final class LifeInsight {
    @Attribute(.unique) var id: UUID
    var date: Date
    var insightType: String
    var title: String
    var insightDescription: String
    var actionableRecommendations: [String]
    var priority: String
    var isRead: Bool

    // periphery:ignore - Reserved: init(id:date:insightType:title:insightDescription:actionableRecommendations:priority:isRead:) initializer — reserved for future feature activation
    init(
        // periphery:ignore - Reserved: init(id:date:insightType:title:insightDescription:actionableRecommendations:priority:isRead:) initializer reserved for future feature activation
        id: UUID = UUID(),
        date: Date = Date(),
        insightType: String,
        title: String,
        insightDescription: String,
        actionableRecommendations: [String] = [],
        priority: String = "medium",
        isRead: Bool = false
    ) {
        self.id = id
        self.date = date
        self.insightType = insightType
        self.title = title
        self.insightDescription = insightDescription
        self.actionableRecommendations = actionableRecommendations
        self.priority = priority
        self.isRead = isRead
    }
}

// MARK: - Window Management Models

@Model
final class WindowState {
    @Attribute(.unique) var id: UUID
    var windowType: String
    var position: Data
    var size: Data
    var conversationID: UUID?
    var projectID: UUID?
    var lastOpened: Date

    // periphery:ignore - Reserved: init(id:windowType:position:size:conversationID:projectID:lastOpened:) initializer reserved for future feature activation
    init(
        id: UUID = UUID(),
        windowType: String,
        position: Data = Data(),
        size: Data = Data(),
        conversationID: UUID? = nil,
        projectID: UUID? = nil,
        lastOpened: Date = Date()
    ) {
        self.id = id
        self.windowType = windowType
        self.position = position
        self.size = size
        self.conversationID = conversationID
        self.projectID = projectID
        self.lastOpened = lastOpened
    }
}

// MARK: - Identifiable Conformance

extension HealthSnapshot: Identifiable {}
extension DailyScreenTimeRecord: Identifiable {}
extension DailyInputStatistics: Identifiable {}
extension BrowsingRecord: Identifiable {}
extension LocationVisitRecord: Identifiable {}
extension LifeInsight: Identifiable {}
extension WindowState: Identifiable {}
