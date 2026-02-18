//
//  StoreKitService.swift
//  Thea
//
//  StoreKit 2 integration for in-app purchases and subscriptions
//

import Combine
import Foundation
import OSLog
import StoreKit
import SwiftUI

// MARK: - Private Logger

private let logger = Logger(subsystem: "com.thea.app", category: "StoreKit")

// MARK: - StoreKit Service

@MainActor
public class StoreKitService: ObservableObject {
    public static let shared = StoreKitService()

    // MARK: - Published State

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: StoreError?

    // MARK: - Product Identifiers

    public enum ProductID: String, CaseIterable {
        // Subscriptions
        case monthlyPro = "app.thea.pro.monthly"
        case yearlyPro = "app.thea.pro.yearly"
        case monthlyTeam = "app.thea.team.monthly"
        case yearlyTeam = "app.thea.team.yearly"

        // Consumables
        case aiCredits100 = "app.thea.credits.100"
        case aiCredits500 = "app.thea.credits.500"
        case aiCredits1000 = "app.thea.credits.1000"

        // Non-Consumables
        case lifetimePro = "app.thea.pro.lifetime"
        case premiumThemes = "app.thea.themes.premium"
        case advancedAutomation = "app.thea.automation.advanced"
    }

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Never>?
    private var productsByID: [String: Product] = [:]

    // MARK: - Initialization

    private init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = ProductID.allCases.map(\.rawValue)
            let storeProducts = try await Product.products(for: productIDs)

            products = storeProducts.sorted { $0.price < $1.price }
            productsByID = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })
        } catch {
            self.error = .failedToLoadProducts(error)
        }
    }

    // MARK: - Purchase

    public func purchase(_ productID: ProductID) async throws -> StoreKit.Transaction? {
        guard let product = productsByID[productID.rawValue] else {
            throw StoreError.productNotFound
        }

        return try await purchase(product)
    }

    public func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    public func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Check Subscription Status

    public func checkSubscriptionStatus() async {
        var status: SubscriptionStatus = .notSubscribed

        // Get subscription status from subscribed products
        for product in products where product.type == .autoRenewable {
            if let subscriptionInfo = product.subscription {
                let statuses: [Product.SubscriptionInfo.Status]
                do {
                    statuses = try await subscriptionInfo.status
                } catch {
                    logger.error("Failed to fetch subscription status for \(product.id): \(error.localizedDescription)")
                    continue
                }
                for verificationResult in statuses {
                    switch verificationResult.state {
                    case .subscribed:
                        do {
                            let transaction = try verificationResult.transaction.payloadValue
                            if let expirationDate = transaction.expirationDate {
                                if product.id.contains("team") {
                                    status = .team(expiresAt: expirationDate)
                                } else {
                                    status = .pro(expiresAt: expirationDate)
                                }
                            }
                        } catch {
                            logger.error("Failed to verify subscription transaction for \(product.id): \(error.localizedDescription)")
                        }
                    case .expired:
                        do {
                            let transaction = try verificationResult.transaction.payloadValue
                            if let expirationDate = transaction.expirationDate {
                                status = .expired(expiredAt: expirationDate)
                            }
                        } catch {
                            logger.error("Failed to verify expired transaction for \(product.id): \(error.localizedDescription)")
                        }
                    default:
                        break
                    }
                }
            }
        }

        // Check for lifetime purchase
        if purchasedProductIDs.contains(ProductID.lifetimePro.rawValue) {
            status = .lifetime
        }

        subscriptionStatus = status
    }

    // MARK: - Manage Subscription

    public func showManageSubscription() async {
        #if os(iOS)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                do {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                } catch {
                    logger.error("Failed to show manage subscriptions UI: \(error.localizedDescription)")
                    self.error = .purchaseFailed
                }
            }
        #endif
    }

    // MARK: - Refund Request

    public func requestRefund(for transactionID: UInt64) async throws {
        #if os(iOS)
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                let status = try await StoreKit.Transaction.beginRefundRequest(for: transactionID, in: windowScene)
                switch status {
                case .success:
                    logger.info("Refund request submitted successfully")
                case .userCancelled:
                    logger.info("User cancelled refund request")
                @unknown default:
                    break
                }
            }
        #endif
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            // Listen for unfinished transactions at app start
            for await verificationResult in StoreKit.Transaction.unfinished {
                guard let self else { return }

                if case let .verified(transaction) = verificationResult {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Update Purchased Products

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        // Check each product for active entitlements
        for product in products {
            if product.type == .autoRenewable {
                if let subscription = product.subscription {
                    do {
                        let statuses = try await subscription.status
                        for status in statuses {
                            if status.state == .subscribed {
                                purchased.insert(product.id)
                            }
                        }
                    } catch {
                        logger.error("Failed to check subscription status for \(product.id): \(error.localizedDescription)")
                    }
                }
            } else {
                // For non-subscription products, check if they have an active transaction
                if let _ = await StoreKit.Transaction.latest(for: product.id) {
                    purchased.insert(product.id)
                }
            }
        }

        purchasedProductIDs = purchased
        await checkSubscriptionStatus()
    }

    // MARK: - Verification

    private func checkVerified(_ result: StoreKit.VerificationResult<StoreKit.Transaction>) throws -> StoreKit.Transaction {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case let .verified(safe):
            return safe
        }
    }

    // MARK: - Entitlements

    public func hasEntitlement(_ productID: ProductID) -> Bool {
        purchasedProductIDs.contains(productID.rawValue)
    }

    public var isPro: Bool {
        switch subscriptionStatus {
        case .pro, .team, .lifetime:
            true
        default:
            hasEntitlement(.lifetimePro)
        }
    }

    public var isTeam: Bool {
        if case .team = subscriptionStatus {
            return true
        }
        return false
    }

    public var hasAdvancedAutomation: Bool {
        isPro || hasEntitlement(.advancedAutomation)
    }

    public var hasPremiumThemes: Bool {
        isPro || hasEntitlement(.premiumThemes)
    }

    // MARK: - Credits

    public func purchaseCredits(_ amount: Int) async throws {
        let productID: ProductID = switch amount {
        case ..<200: .aiCredits100
        case ..<750: .aiCredits500
        default: .aiCredits1000
        }

        _ = try await purchase(productID)
    }

    // MARK: - Product Info

    public func product(for id: ProductID) -> Product? {
        productsByID[id.rawValue]
    }

    public var subscriptionProducts: [Product] {
        products.filter { $0.type == .autoRenewable }
    }

    public var consumableProducts: [Product] {
        products.filter { $0.type == .consumable }
    }

    public var nonConsumableProducts: [Product] {
        products.filter { $0.type == .nonConsumable }
    }

    // MARK: - Price Formatting

    public func formattedPrice(for productID: ProductID) -> String? {
        guard let product = product(for: productID) else { return nil }
        return product.displayPrice
    }

    public func subscriptionPeriod(for productID: ProductID) -> String? {
        guard let product = product(for: productID),
              let subscription = product.subscription else { return nil }

        switch subscription.subscriptionPeriod.unit {
        case .day: return "\(subscription.subscriptionPeriod.value) day(s)"
        case .week: return "\(subscription.subscriptionPeriod.value) week(s)"
        case .month: return "\(subscription.subscriptionPeriod.value) month(s)"
        case .year: return "\(subscription.subscriptionPeriod.value) year(s)"
        @unknown default: return nil
        }
    }
}

// MARK: - Subscription Status

public enum SubscriptionStatus: Sendable {
    case notSubscribed
    case pro(expiresAt: Date)
    case team(expiresAt: Date)
    case lifetime
    case expired(expiredAt: Date)

    public var isActive: Bool {
        switch self {
        case .pro, .team, .lifetime:
            true
        case .notSubscribed, .expired:
            false
        }
    }

    public var displayName: String {
        switch self {
        case .notSubscribed: "Free"
        case .pro: "Pro"
        case .team: "Team"
        case .lifetime: "Lifetime Pro"
        case .expired: "Expired"
        }
    }
}

// MARK: - Store Error

public enum StoreError: Error, LocalizedError, Sendable {
    case failedVerification
    case productNotFound
    case purchaseFailed
    case failedToLoadProducts(Error)

    public var errorDescription: String? {
        switch self {
        case .failedVerification:
            "Transaction verification failed"
        case .productNotFound:
            "Product not found"
        case .purchaseFailed:
            "Purchase failed"
        case let .failedToLoadProducts(error):
            "Failed to load products: \(error.localizedDescription)"
        }
    }
}

// MARK: - SwiftUI Views

public struct SubscriptionBadge: View {
    @ObservedObject private var store = StoreKitService.shared

    public init() {}

    public var body: some View {
        Group {
            if store.isPro {
                Text(store.subscriptionStatus.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
        }
    }
}

public struct ProductPurchaseButton: View {
    let product: Product
    @ObservedObject private var store = StoreKitService.shared
    @State private var isPurchasing = false
    @State private var error: Error?

    public init(product: Product) {
        self.product = product
    }

    public var body: some View {
        Button {
            Task {
                isPurchasing = true
                defer { isPurchasing = false }

                do {
                    _ = try await store.purchase(product)
                } catch {
                    self.error = error
                }
            }
        } label: {
            if isPurchasing {
                ProgressView()
            } else if store.purchasedProductIDs.contains(product.id) {
                Text("Purchased")
            } else {
                Text(product.displayPrice)
            }
        }
        .disabled(isPurchasing || store.purchasedProductIDs.contains(product.id))
    }
}
