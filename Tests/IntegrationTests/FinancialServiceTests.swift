import Foundation
import Testing
@testable import TheaCore

/// Tests for financial services
@Suite("Financial Service Tests")
struct FinancialServiceTests {
    // MARK: - Budget Service Tests

    @Test("Create budget")
    func testCreateBudget() async throws {
        let service = BudgetService()

        let budget = Budget(
            name: "January Budget",
            month: Date(),
            totalIncome: 5_000,
            categories: []
        )

        try await service.createBudget(budget)

        let fetched = try await service.fetchBudget(for: Date())
        #expect(fetched != nil)
        #expect(fetched?.totalIncome == 5_000)
    }

    @Test("Allocate funds to category")
    func testAllocateFunds() async throws {
        let service = BudgetService()

        let category = BudgetCategory(
            name: "Housing",
            allocated: 0,
            category: .housing
        )

        var budget = Budget(
            name: "Test Budget",
            month: Date(),
            totalIncome: 5_000,
            categories: [category]
        )

        try await service.createBudget(budget)

        try await service.allocateFunds(budgetID: budget.id, categoryID: category.id, amount: 1_500)

        let allocated = await service.getTotalAllocated(budgetID: budget.id)
        #expect(allocated == 1_500)
    }

    // MARK: - Transaction Categorizer Tests

    @Test("Auto-categorize transaction")
    func testAutoCategorize() async throws {
        let service = TransactionCategorizerService()

        let transaction = Transaction(
            amount: -50,
            description: "Netflix subscription",
            category: .other
        )

        let category = try await service.categorizeTransaction(transaction)
        #expect(category == .entertainment)
    }

    @Test("Categorize based on merchant")
    func testCategorizeMerchant() async throws {
        let service = TransactionCategorizerService()

        let transaction = Transaction(
            amount: -100,
            description: "Purchase",
            category: .other,
            merchant: "Whole Foods"
        )

        let category = try await service.categorizeTransaction(transaction)
        #expect(category == .food)
    }

    @Test("Categorize income")
    func testCategorizeIncome() async throws {
        let service = TransactionCategorizerService()

        let transaction = Transaction(
            amount: 5_000,
            description: "Salary deposit",
            category: .other
        )

        let category = try await service.categorizeTransaction(transaction)
        #expect(category == .income)
    }

    // MARK: - Subscription Monitor Tests

    @Test("Add subscription")
    func testAddSubscription() async throws {
        let service = SubscriptionMonitorService()

        let subscription = Subscription(
            name: "Spotify",
            amount: 9.99,
            billingCycle: .monthly,
            nextBillingDate: Date()
        )

        try await service.addSubscription(subscription)

        let subscriptions = try await service.fetchSubscriptions()
        #expect(!subscriptions.isEmpty)
        #expect(subscriptions.first?.name == "Spotify")
    }

    @Test("Calculate total monthly cost")
    func testTotalMonthlyCost() async throws {
        let service = SubscriptionMonitorService()

        let sub1 = Subscription(name: "Netflix", amount: 15.99, billingCycle: .monthly, nextBillingDate: Date())
        let sub2 = Subscription(name: "Spotify", amount: 9.99, billingCycle: .monthly, nextBillingDate: Date())

        try await service.addSubscription(sub1)
        try await service.addSubscription(sub2)

        let total = try await service.getTotalMonthlyCost()
        #expect(abs(total - 25.98) < 0.01)
    }

    @Test("Get upcoming renewals")
    func testUpcomingRenewals() async throws {
        let service = SubscriptionMonitorService()

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 8, to: Date())!

        let sub1 = Subscription(name: "Netflix", amount: 15.99, billingCycle: .monthly, nextBillingDate: tomorrow)
        let sub2 = Subscription(name: "Spotify", amount: 9.99, billingCycle: .monthly, nextBillingDate: nextWeek)

        try await service.addSubscription(sub1)
        try await service.addSubscription(sub2)

        let upcoming = try await service.getUpcomingRenewals(days: 7)
        #expect(upcoming.count == 1)
        #expect(upcoming.first?.name == "Netflix")
    }

    // MARK: - Budget Models Tests

    @Test("Budget category percentage calculation")
    func testCategoryPercentage() {
        let category = BudgetCategory(
            name: "Housing",
            allocated: 1_000,
            spent: 750,
            category: .housing
        )

        #expect(category.percentageUsed == 75.0)
        #expect(category.remaining == 250)
        #expect(category.status == .good)
    }

    @Test("Budget category over budget")
    func testCategoryOverBudget() {
        let category = BudgetCategory(
            name: "Food",
            allocated: 500,
            spent: 600,
            category: .food
        )

        #expect(category.percentageUsed == 120.0)
        #expect(category.remaining == -100)
        #expect(category.status == .over)
    }

    @Test("Budget balance check")
    func testBudgetBalance() {
        let categories = [
            BudgetCategory(name: "Housing", allocated: 1_500, category: .housing),
            BudgetCategory(name: "Food", allocated: 500, category: .food),
            BudgetCategory(name: "Transport", allocated: 300, category: .transportation)
        ]

        var budget = Budget(
            name: "Test",
            month: Date(),
            totalIncome: 2_300,
            categories: categories
        )

        budget.unallocated = budget.totalIncome - budget.totalAllocated

        #expect(budget.isBalanced)
        #expect(budget.totalAllocated == 2_300)
    }

    // MARK: - Subscription Models Tests

    @Test("Subscription monthly cost calculation")
    func testSubscriptionMonthlyCost() {
        let weekly = Subscription(name: "Test", amount: 10, billingCycle: .weekly, nextBillingDate: Date())
        #expect(abs(weekly.monthlyCost - 43.3) < 0.1)

        let monthly = Subscription(name: "Test", amount: 10, billingCycle: .monthly, nextBillingDate: Date())
        #expect(monthly.monthlyCost == 10)

        let quarterly = Subscription(name: "Test", amount: 30, billingCycle: .quarterly, nextBillingDate: Date())
        #expect(quarterly.monthlyCost == 10)

        let yearly = Subscription(name: "Test", amount: 120, billingCycle: .yearly, nextBillingDate: Date())
        #expect(yearly.monthlyCost == 10)
    }

    @Test("Subscription annual cost")
    func testSubscriptionAnnualCost() {
        let subscription = Subscription(
            name: "Netflix",
            amount: 15.99,
            billingCycle: .monthly,
            nextBillingDate: Date()
        )

        let annual = subscription.annualCost
        #expect(abs(annual - 191.88) < 0.01)
    }

    // MARK: - Transaction Category Tests

    @Test("Category keywords for auto-categorization")
    func testCategoryKeywords() {
        #expect(TransactionCategory.food.keywords.contains("restaurant"))
        #expect(TransactionCategory.transportation.keywords.contains("uber"))
        #expect(TransactionCategory.entertainment.keywords.contains("netflix"))
    }
}
