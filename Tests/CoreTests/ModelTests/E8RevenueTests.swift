import Foundation
import Testing

// MARK: - E8 Revenue Tests

// Test doubles that mirror production types for SPM testing

private enum TestProductID: String, CaseIterable {
    case monthlyPro = "app.thea.pro.monthly"
    case yearlyPro = "app.thea.pro.yearly"
    case monthlyTeam = "app.thea.team.monthly"
    case yearlyTeam = "app.thea.team.yearly"
    case aiCredits100 = "app.thea.credits.100"
    case aiCredits500 = "app.thea.credits.500"
    case aiCredits1000 = "app.thea.credits.1000"
    case lifetimePro = "app.thea.pro.lifetime"
    case premiumThemes = "app.thea.themes.premium"
    case advancedAutomation = "app.thea.automation.advanced"
}

private enum TestSubscriptionStatus: Sendable {
    case notSubscribed
    case pro(expiresAt: Date)
    case team(expiresAt: Date)
    case lifetime
    case expired(expiredAt: Date)

    var isActive: Bool {
        switch self {
        case .pro, .team, .lifetime: true
        case .notSubscribed, .expired: false
        }
    }

    var displayName: String {
        switch self {
        case .notSubscribed: "Free"
        case .pro: "Pro"
        case .team: "Team"
        case .lifetime: "Lifetime Pro"
        case .expired: "Expired"
        }
    }
}

private enum TestStoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    case failedToLoadProducts(String)

    var errorDescription: String? {
        switch self {
        case .failedVerification: "Transaction verification failed"
        case .productNotFound: "Product not found"
        case .purchaseFailed: "Purchase failed"
        case let .failedToLoadProducts(reason): "Failed to load products: \(reason)"
        }
    }
}

private enum TestProFeature: String, CaseIterable {
    case unlimitedProviders = "Unlimited AI Providers"
    case modelComparison = "Model Comparison Mode"
    case advancedAgents = "Advanced Agent Delegation"
    case customSystemPrompts = "Custom System Prompts"
    case verificationPipeline = "Response Verification"
    case smartRouting = "Smart Model Routing"
    case conversationForking = "Conversation Forking"
    case healthDashboard = "Health Dashboard"
    case financialTracking = "Financial Tracking"
    case privacyFirewall = "Privacy Firewall"
    case crossDeviceSync = "Cross-Device Sync"
    case encryptedSync = "End-to-End Encrypted Sync"
    case premiumThemes = "Premium Themes"
    case advancedAutomation = "Advanced Automation"

    var description: String {
        switch self {
        case .unlimitedProviders: "Connect to unlimited AI providers"
        case .modelComparison: "Compare responses from multiple models side-by-side"
        case .advancedAgents: "Delegate complex tasks to specialized AI agents"
        case .customSystemPrompts: "Customize AI personality and behavior per conversation"
        case .verificationPipeline: "Verify AI responses with multi-source fact-checking"
        case .smartRouting: "Automatically route queries to the best AI model"
        case .conversationForking: "Branch conversations to explore different directions"
        case .healthDashboard: "HealthKit integration with trend analysis and coaching"
        case .financialTracking: "Transaction tracking, budgets, and tax estimation"
        case .privacyFirewall: "Default-deny outbound data firewall with audit log"
        case .crossDeviceSync: "Sync conversations and data across all your devices"
        case .encryptedSync: "AES-256-GCM encryption for all synced data"
        case .premiumThemes: "Additional visual themes and customization options"
        case .advancedAutomation: "Autonomous task execution and workflow automation"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedProviders: "server.rack"
        case .modelComparison: "rectangle.split.2x1"
        case .advancedAgents: "person.2.circle"
        case .customSystemPrompts: "text.bubble"
        case .verificationPipeline: "checkmark.shield"
        case .smartRouting: "arrow.triangle.branch"
        case .conversationForking: "arrow.branch"
        case .healthDashboard: "heart.fill"
        case .financialTracking: "chart.bar.fill"
        case .privacyFirewall: "lock.shield"
        case .crossDeviceSync: "arrow.triangle.2.circlepath"
        case .encryptedSync: "lock.fill"
        case .premiumThemes: "paintpalette"
        case .advancedAutomation: "gearshape.2"
        }
    }

    static let freeFeatures: Set<TestProFeature> = [.customSystemPrompts, .conversationForking]
}

private enum TestSubscriptionTier: String, CaseIterable {
    case free = "Free"
    case pro = "Pro"
    case team = "Team"

    var features: [TestProFeature] {
        switch self {
        case .free: Array(TestProFeature.freeFeatures)
        case .pro: TestProFeature.allCases.filter { $0 != .advancedAgents }
        case .team: TestProFeature.allCases
        }
    }

    var monthlyPrice: String {
        switch self {
        case .free: "Free"
        case .pro: "$9.99/mo"
        case .team: "$29.99/mo"
        }
    }

    var annualPrice: String {
        switch self {
        case .free: "Free"
        case .pro: "$99.99/yr"
        case .team: "$299.99/yr"
        }
    }

    var badge: String {
        switch self {
        case .free: ""
        case .pro: "PRO"
        case .team: "TEAM"
        }
    }
}

/// Feature gate logic (mirrors FeatureGate)
private struct TestFeatureGate {
    let isPro: Bool
    let isTeam: Bool
    let purchasedProducts: Set<String>

    func isAvailable(_ feature: TestProFeature) -> Bool {
        if TestProFeature.freeFeatures.contains(feature) { return true }
        if isPro {
            if feature == .advancedAgents { return isTeam }
            return true
        }
        switch feature {
        case .premiumThemes:
            return purchasedProducts.contains(TestProductID.premiumThemes.rawValue)
        case .advancedAutomation:
            return purchasedProducts.contains(TestProductID.advancedAutomation.rawValue)
        default:
            return false
        }
    }

    var currentTier: TestSubscriptionTier {
        if isTeam { return .team }
        if isPro { return .pro }
        return .free
    }

    var maxProviders: Int {
        switch currentTier {
        case .free: 1
        case .pro, .team: .max
        }
    }

    var dailyMessageLimit: Int {
        switch currentTier {
        case .free: 50
        case .pro, .team: .max
        }
    }
}

// MARK: - Product ID Tests

@Suite("Product IDs")
struct ProductIDTests {
    @Test("All product IDs are unique")
    func uniqueIDs() {
        let ids = TestProductID.allCases.map(\.rawValue)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Has 10 products total")
    func productCount() {
        #expect(TestProductID.allCases.count == 10)
    }

    @Test("Subscription products have correct prefix")
    func subscriptionPrefix() {
        let subs: [TestProductID] = [.monthlyPro, .yearlyPro, .monthlyTeam, .yearlyTeam]
        for sub in subs {
            #expect(sub.rawValue.hasPrefix("app.thea."))
        }
    }

    @Test("Consumable products have credits prefix")
    func consumablePrefix() {
        let consumables: [TestProductID] = [.aiCredits100, .aiCredits500, .aiCredits1000]
        for c in consumables {
            #expect(c.rawValue.contains("credits"))
        }
    }

    @Test("Non-consumable products exist")
    func nonConsumables() {
        #expect(TestProductID.lifetimePro.rawValue == "app.thea.pro.lifetime")
        #expect(TestProductID.premiumThemes.rawValue == "app.thea.themes.premium")
        #expect(TestProductID.advancedAutomation.rawValue == "app.thea.automation.advanced")
    }
}

// MARK: - Subscription Status Tests

@Suite("Subscription Status")
struct SubscriptionStatusTests {
    @Test("Not subscribed is inactive")
    func notSubscribed() {
        let status = TestSubscriptionStatus.notSubscribed
        #expect(!status.isActive)
        #expect(status.displayName == "Free")
    }

    @Test("Pro is active")
    func proActive() {
        let status = TestSubscriptionStatus.pro(expiresAt: Date().addingTimeInterval(86400))
        #expect(status.isActive)
        #expect(status.displayName == "Pro")
    }

    @Test("Team is active")
    func teamActive() {
        let status = TestSubscriptionStatus.team(expiresAt: Date().addingTimeInterval(86400))
        #expect(status.isActive)
        #expect(status.displayName == "Team")
    }

    @Test("Lifetime is active")
    func lifetimeActive() {
        let status = TestSubscriptionStatus.lifetime
        #expect(status.isActive)
        #expect(status.displayName == "Lifetime Pro")
    }

    @Test("Expired is inactive")
    func expiredInactive() {
        let status = TestSubscriptionStatus.expired(expiredAt: Date().addingTimeInterval(-86400))
        #expect(!status.isActive)
        #expect(status.displayName == "Expired")
    }
}

// MARK: - Store Error Tests

@Suite("Store Errors")
struct StoreErrorTests {
    @Test("Error descriptions are non-empty")
    func errorDescriptions() {
        let errors: [TestStoreError] = [
            .failedVerification,
            .productNotFound,
            .purchaseFailed,
            .failedToLoadProducts("network")
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("Failed to load includes reason")
    func loadErrorReason() {
        let error = TestStoreError.failedToLoadProducts("network timeout")
        #expect(error.errorDescription?.contains("network timeout") == true)
    }
}

// MARK: - Pro Feature Tests

@Suite("Pro Features")
struct ProFeatureTests {
    @Test("All features have descriptions")
    func descriptions() {
        for feature in TestProFeature.allCases {
            #expect(!feature.description.isEmpty)
        }
    }

    @Test("All features have icons")
    func icons() {
        for feature in TestProFeature.allCases {
            #expect(!feature.icon.isEmpty)
        }
    }

    @Test("Feature count is 14")
    func featureCount() {
        #expect(TestProFeature.allCases.count == 14)
    }

    @Test("Free features are subset of all features")
    func freeSubset() {
        for feature in TestProFeature.freeFeatures {
            #expect(TestProFeature.allCases.contains(feature))
        }
    }

    @Test("Free tier has exactly 2 features")
    func freeFeaturesCount() {
        #expect(TestProFeature.freeFeatures.count == 2)
    }

    @Test("Custom system prompts is free")
    func customPromptsIsFree() {
        #expect(TestProFeature.freeFeatures.contains(.customSystemPrompts))
    }

    @Test("Conversation forking is free")
    func forkingIsFree() {
        #expect(TestProFeature.freeFeatures.contains(.conversationForking))
    }

    @Test("Advanced agents is NOT free")
    func agentsNotFree() {
        #expect(!TestProFeature.freeFeatures.contains(.advancedAgents))
    }
}

// MARK: - Subscription Tier Tests

@Suite("Subscription Tiers")
struct SubscriptionTierTests {
    @Test("Three tiers exist")
    func tierCount() {
        #expect(TestSubscriptionTier.allCases.count == 3)
    }

    @Test("Free tier has limited features")
    func freeFeatures() {
        let free = TestSubscriptionTier.free
        #expect(free.features.count == 2)
        #expect(free.monthlyPrice == "Free")
    }

    @Test("Pro tier has most features")
    func proFeatures() {
        let pro = TestSubscriptionTier.pro
        #expect(pro.features.count == 13) // All except advancedAgents
        #expect(!pro.features.contains(.advancedAgents))
    }

    @Test("Team tier has all features")
    func teamFeatures() {
        let team = TestSubscriptionTier.team
        #expect(team.features.count == 14)
        #expect(team.features.contains(.advancedAgents))
    }

    @Test("Pro is cheaper than Team")
    func pricing() {
        #expect(TestSubscriptionTier.pro.monthlyPrice == "$9.99/mo")
        #expect(TestSubscriptionTier.team.monthlyPrice == "$29.99/mo")
    }

    @Test("Annual prices exist")
    func annualPricing() {
        #expect(TestSubscriptionTier.pro.annualPrice == "$99.99/yr")
        #expect(TestSubscriptionTier.team.annualPrice == "$299.99/yr")
    }

    @Test("Badges are correct")
    func badges() {
        #expect(TestSubscriptionTier.free.badge.isEmpty)
        #expect(TestSubscriptionTier.pro.badge == "PRO")
        #expect(TestSubscriptionTier.team.badge == "TEAM")
    }
}

// MARK: - Feature Gate Tests

@Suite("Feature Gate")
struct FeatureGateTests {
    @Test("Free user gets free features only")
    func freeUserAccess() {
        let gate = TestFeatureGate(isPro: false, isTeam: false, purchasedProducts: [])
        #expect(gate.isAvailable(.customSystemPrompts))
        #expect(gate.isAvailable(.conversationForking))
        #expect(!gate.isAvailable(.unlimitedProviders))
        #expect(!gate.isAvailable(.modelComparison))
        #expect(!gate.isAvailable(.healthDashboard))
    }

    @Test("Pro user gets all except team features")
    func proUserAccess() {
        let gate = TestFeatureGate(isPro: true, isTeam: false, purchasedProducts: [])
        #expect(gate.isAvailable(.unlimitedProviders))
        #expect(gate.isAvailable(.modelComparison))
        #expect(gate.isAvailable(.healthDashboard))
        #expect(gate.isAvailable(.premiumThemes))
        #expect(!gate.isAvailable(.advancedAgents))
    }

    @Test("Team user gets all features")
    func teamUserAccess() {
        let gate = TestFeatureGate(isPro: true, isTeam: true, purchasedProducts: [])
        #expect(gate.isAvailable(.advancedAgents))
        #expect(gate.isAvailable(.unlimitedProviders))
        #expect(gate.isAvailable(.healthDashboard))
    }

    @Test("Individual purchase of themes")
    func themesPurchase() {
        let gate = TestFeatureGate(isPro: false, isTeam: false, purchasedProducts: ["app.thea.themes.premium"])
        #expect(gate.isAvailable(.premiumThemes))
        #expect(!gate.isAvailable(.unlimitedProviders))
    }

    @Test("Individual purchase of automation")
    func automationPurchase() {
        let gate = TestFeatureGate(isPro: false, isTeam: false, purchasedProducts: ["app.thea.automation.advanced"])
        #expect(gate.isAvailable(.advancedAutomation))
        #expect(!gate.isAvailable(.unlimitedProviders))
    }

    @Test("Current tier detection")
    func tierDetection() {
        #expect(TestFeatureGate(isPro: false, isTeam: false, purchasedProducts: []).currentTier == .free)
        #expect(TestFeatureGate(isPro: true, isTeam: false, purchasedProducts: []).currentTier == .pro)
        #expect(TestFeatureGate(isPro: true, isTeam: true, purchasedProducts: []).currentTier == .team)
    }

    @Test("Free tier limits")
    func freeLimits() {
        let gate = TestFeatureGate(isPro: false, isTeam: false, purchasedProducts: [])
        #expect(gate.maxProviders == 1)
        #expect(gate.dailyMessageLimit == 50)
    }

    @Test("Pro tier unlimited")
    func proUnlimited() {
        let gate = TestFeatureGate(isPro: true, isTeam: false, purchasedProducts: [])
        #expect(gate.maxProviders == .max)
        #expect(gate.dailyMessageLimit == .max)
    }
}
