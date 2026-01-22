//
//  StoreKitService.swift
//  Thea
//
//  StoreKit 2 integration for in-app purchases and subscriptions
//

import Foundation
import StoreKit
import Combine

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
            let productIDs = ProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)

            products = storeProducts.sorted { $0.price < $1.price }
            productsByID = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })
        } catch {
            self.error = .failedToLoadProducts(error)
        }
    }

    // MARK: - Purchase

    public func purchase(_ productID: ProductID) async throws -> Transaction? {
        guard let product = productsByID[productID.rawValue] else {
            throw StoreError.productNotFound
        }

        return try await purchase(product)
    }

    public func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
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

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productType == .autoRenewable {
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        if transaction.productID.contains("team") {
                            status = .team(expiresAt: expirationDate)
                        } else {
                            status = .pro(expiresAt: expirationDate)
                        }
                    } else {
                        status = .expired(expiredAt: expirationDate)
                    }
                }
            } else if transaction.productID == ProductID.lifetimePro.rawValue {
                status = .lifetime
            }
        }

        subscriptionStatus = status
    }

    // MARK: - Manage Subscription

    public func showManageSubscription() async {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            try? await AppStore.showManageSubscriptions(in: windowScene)
        }
        #endif
    }

    // MARK: - Refund Request

    public func requestRefund(for transactionID: UInt64) async throws {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            try await Transaction.beginRefundRequest(for: transactionID, in: windowScene)
        }
        #endif
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                if case .verified(let transaction) = result {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Update Purchased Products

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            purchased.insert(transaction.productID)
        }

        purchasedProductIDs = purchased
        await checkSubscriptionStatus()
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Entitlements

    public func hasEntitlement(_ productID: ProductID) -> Bool {
        return purchasedProductIDs.contains(productID.rawValue)
    }

    public var isPro: Bool {
        switch subscriptionStatus {
        case .pro, .team, .lifetime:
            return true
        default:
            return hasEntitlement(.lifetimePro)
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
        let productID: ProductID
        switch amount {
        case ..<200: productID = .aiCredits100
        case ..<750: productID = .aiCredits500
        default: productID = .aiCredits1000
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
            return true
        case .notSubscribed, .expired:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .notSubscribed: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        case .lifetime: return "Lifetime Pro"
        case .expired: return "Expired"
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
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        case .failedToLoadProducts(let error):
            return "Failed to load products: \(error.localizedDescription)"
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
