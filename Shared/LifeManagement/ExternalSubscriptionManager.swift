// ExternalSubscriptionManager.swift
// Thea — Track external service subscriptions
//
// Manages user subscriptions to external services (Netflix, Spotify,
// AWS, gym, etc.) with renewal reminders, cost analytics, and
// category-based spending breakdown.

import Foundation
import OSLog

private let subLogger = Logger(subsystem: "ai.thea.app", category: "ExternalSubscriptionManager")

// MARK: - Models

/// An external subscription the user pays for.
struct ExternalSubscription: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var provider: String
    var category: SubscriptionCategory
    var cost: Double
    var currency: String
    var billingCycle: BillingCycle
    var startDate: Date
    var nextRenewalDate: Date
    var isActive: Bool
    var autoRenew: Bool
    var notes: String
    var url: String?
    var createdAt: Date

    init(
        name: String, provider: String = "", category: SubscriptionCategory = .other,
        cost: Double, currency: String = "CHF", billingCycle: BillingCycle = .monthly,
        startDate: Date = Date(), nextRenewalDate: Date? = nil,
        isActive: Bool = true, autoRenew: Bool = true, notes: String = "", url: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.provider = provider
        self.category = category
        self.cost = cost
        self.currency = currency
        self.billingCycle = billingCycle
        self.startDate = startDate
        self.nextRenewalDate = nextRenewalDate ?? billingCycle.nextDate(from: startDate)
        self.isActive = isActive
        self.autoRenew = autoRenew
        self.notes = notes
        self.url = url
        self.createdAt = Date()
    }

    /// Monthly equivalent cost for comparison.
    var monthlyCost: Double {
        switch billingCycle {
        case .weekly: cost * 52 / 12
        case .monthly: cost
        case .quarterly: cost / 3
        case .semiAnnual: cost / 6
        case .annual: cost / 12
        case .lifetime: 0
        }
    }

    /// Annual equivalent cost.
    var annualCost: Double {
        monthlyCost * 12
    }

    var isRenewalSoon: Bool {
        let daysUntilRenewal = Calendar.current.dateComponents([.day], from: Date(), to: nextRenewalDate).day ?? 0
        return daysUntilRenewal <= 7 && daysUntilRenewal >= 0
    }

    var isOverdue: Bool {
        nextRenewalDate < Date()
    }
}

enum SubscriptionCategory: String, Codable, Sendable, CaseIterable {
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

enum BillingCycle: String, Codable, Sendable, CaseIterable {
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

// MARK: - Manager

@MainActor
final class ExternalSubscriptionManager: ObservableObject {
    static let shared = ExternalSubscriptionManager()

    @Published private(set) var subscriptions: [ExternalSubscription] = []

    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/LifeManagement", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            subLogger.error("Failed to create storage directory: \(error.localizedDescription)")
        }
        storageURL = dir.appendingPathComponent("subscriptions.json")
        loadState()
    }

    // MARK: - CRUD

    func addSubscription(_ sub: ExternalSubscription) {
        subscriptions.append(sub)
        save()
        subLogger.info("Added subscription: \(sub.name) (\(sub.billingCycle.displayName) \(sub.currency) \(sub.cost))")
    }

    func updateSubscription(_ sub: ExternalSubscription) {
        // periphery:ignore - Reserved: updateSubscription(_:) instance method reserved for future feature activation
        if let idx = subscriptions.firstIndex(where: { $0.id == sub.id }) {
            subscriptions[idx] = sub
            save()
        }
    }

    func deleteSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        save()
    }

    // periphery:ignore - Reserved: cancelSubscription(id:) instance method reserved for future feature activation
    func cancelSubscription(id: UUID) {
        if let idx = subscriptions.firstIndex(where: { $0.id == id }) {
            subscriptions[idx].isActive = false
            subscriptions[idx].autoRenew = false
            save()
        }
    }

    // MARK: - Analytics

    var activeSubscriptions: [ExternalSubscription] {
        subscriptions.filter(\.isActive)
    }

    var totalMonthlyCost: Double {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    var totalAnnualCost: Double {
        totalMonthlyCost * 12
    }

    var costByCategory: [(category: SubscriptionCategory, monthly: Double)] {
        let grouped = Dictionary(grouping: activeSubscriptions, by: \.category)
        return grouped.map { (category: $0.key, monthly: $0.value.reduce(0) { $0 + $1.monthlyCost }) }
            .sorted { $0.monthly > $1.monthly }
    }

    var renewingSoon: [ExternalSubscription] {
        activeSubscriptions.filter(\.isRenewalSoon).sorted { $0.nextRenewalDate < $1.nextRenewalDate }
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(subscriptions)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            subLogger.error("Failed to save subscription data: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            subLogger.error("Failed to read subscription data: \(error.localizedDescription)")
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            subscriptions = try decoder.decode([ExternalSubscription].self, from: data)
        } catch {
            subLogger.error("Failed to decode subscription data: \(error.localizedDescription)")
        }
    }
}
