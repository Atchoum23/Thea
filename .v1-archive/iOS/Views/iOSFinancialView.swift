import SwiftUI

struct iOSFinancialView: View {
    @State private var financialManager = FinancialManager.shared

    @State private var selectedTab: FinancialTab = .overview
    @State private var showingAddAccount = false

    enum FinancialTab: String, CaseIterable {
        case overview = "Overview"
        case transactions = "Transactions"
        case insights = "Insights"

        var icon: String {
            switch self {
            case .overview: "chart.pie.fill"
            case .transactions: "list.bullet"
            case .insights: "lightbulb.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if financialManager.accounts.isEmpty {
                emptyStateView
            } else {
                tabPicker
                tabContent
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            iOSAddAccountView()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.theaPrimary)

            Text("No Accounts Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect your financial accounts to track spending and get AI-powered insights")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingAddAccount = true
            } label: {
                Label("Connect Account", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.theaPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var tabPicker: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(FinancialTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            OverviewTabView()
        case .transactions:
            TransactionsTabView()
        case .insights:
            InsightsTabView()
        }
    }
}

// MARK: - Overview Tab

struct OverviewTabView: View {
    @State private var financialManager = FinancialManager.shared
    @State private var selectedAccount: FinancialAccount?
    @State private var selectedPeriod: TimePeriod = .month

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                accountPicker

                if let account = selectedAccount {
                    periodPicker
                    balanceCard(for: account)
                    spendingChart(for: account)
                    categoryBreakdown(for: account)
                }
            }
            .padding()
        }
        .onAppear {
            if selectedAccount == nil {
                selectedAccount = financialManager.accounts.first
            }
        }
    }

    private var accountPicker: some View {
        Menu {
            ForEach(financialManager.accounts) { account in
                Button {
                    selectedAccount = account
                } label: {
                    Label(account.name, systemImage: selectedAccount?.id == account.id ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selectedAccount?.name ?? "Select Account")
                        .font(.headline)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Week").tag(TimePeriod.week)
            Text("Month").tag(TimePeriod.month)
            Text("Quarter").tag(TimePeriod.quarter)
            Text("Year").tag(TimePeriod.year)
        }
        .pickerStyle(.segmented)
    }

    private func balanceCard(for account: FinancialAccount) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if financialManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task {
                            await financialManager.syncAccount(account)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                }
            }

            Text(formatCurrency(Decimal(account.balance), currency: account.currency))
                .font(.system(size: 36, weight: .bold))

            Text("Last synced \(account.updatedAt, style: .relative)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.theaPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func spendingChart(for account: FinancialAccount) -> some View {
        // Get transactions for this account and calculate monthly data
        let accountTransactions = financialManager.transactions.filter { $0.accountId == account.id }
        let monthlyData = calculateMonthlyData(from: accountTransactions, months: 6)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Spending Trend")
                .font(.headline)

            if monthlyData.isEmpty {
                Text("No transaction data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Simple bar chart visualization
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(monthlyData) { data in
                        VStack(spacing: 4) {
                            Spacer()

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.theaPrimary)
                                .frame(height: barHeight(for: data.expenses, in: monthlyData))

                            Text(data.month)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func calculateMonthlyData(from transactions: [FinancialTransaction], months _: Int) -> [MonthlyData] {
        let calendar = Calendar.current
        _ = Date()

        var monthlyTotals: [String: (income: Decimal, expenses: Decimal)] = [:]

        for transaction in transactions {
            let monthKey = calendar.dateComponents([.year, .month], from: transaction.date)
            guard let date = calendar.date(from: monthKey) else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let monthString = formatter.string(from: date)

            if transaction.amount < 0 {
                monthlyTotals[monthString, default: (0, 0)].expenses += Decimal(abs(transaction.amount))
            } else {
                monthlyTotals[monthString, default: (0, 0)].income += Decimal(transaction.amount)
            }
        }

        return monthlyTotals.map { month, totals in
            MonthlyData(month: month, income: totals.income, expenses: totals.expenses)
        }.sorted { $0.month < $1.month }
    }

    private func categoryBreakdown(for account: FinancialAccount) -> some View {
        let categorySpending = financialManager.getSpendingByCategory()
        let sortedCategories = categorySpending.sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)

            if sortedCategories.isEmpty {
                Text("No transactions in this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(sortedCategories.prefix(5), id: \.key) { category, amount in
                    CategoryRow(
                        category: category,
                        amount: Decimal(amount),
                        currency: account.currency,
                        percentage: calculatePercentage(amount, in: categorySpending)
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func barHeight(for value: Decimal, in data: [MonthlyData]) -> CGFloat {
        let maxExpense = data.map(\.expenses).max() ?? 1
        let ratio = Double(truncating: value as NSNumber) / Double(truncating: maxExpense as NSNumber)
        return CGFloat(ratio) * 120
    }

    private func calculatePercentage(_ amount: Double, in spending: [String: Double]) -> Double {
        let total = spending.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return (amount / total) * 100
    }

    private func formatCurrency(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}

struct CategoryRow: View {
    let category: String
    let amount: Decimal
    let currency: String
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(category))
                .font(.title3)
                .foregroundStyle(.theaPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.body)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.theaPrimary)
                            .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            Text(formatCurrency(amount, currency: currency))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "groceries": "cart.fill"
        case "dining": "fork.knife"
        case "transportation": "car.fill"
        case "entertainment": "tv.fill"
        case "shopping": "bag.fill"
        default: "circle.fill"
        }
    }

    private func formatCurrency(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}

// MARK: - Transactions Tab

struct TransactionsTabView: View {
    @State private var financialManager = FinancialManager.shared
    @State private var selectedAccount: FinancialAccount?

    var body: some View {
        Group {
            if let account = selectedAccount {
                let accountTransactions = financialManager.transactions
                    .filter { $0.accountId == account.id }
                    .sorted { $0.date > $1.date }

                List {
                    ForEach(accountTransactions) { transaction in
                        TransactionRowView(transaction: transaction, currency: account.currency)
                    }
                }
                .listStyle(.plain)
            } else {
                Text("Select an account")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if selectedAccount == nil {
                selectedAccount = financialManager.accounts.first
            }
        }
    }
}

struct TransactionRowView: View {
    let transaction: FinancialTransaction
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(transaction.category ?? "Other"))
                .font(.title3)
                .foregroundStyle(transaction.amount > 0 ? .green : .theaPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionDescription)
                    .font(.body)

                if let merchant = transaction.merchant {
                    Text(merchant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(formatCurrency(Decimal(transaction.amount), currency: currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.amount > 0 ? .green : .primary)
        }
        .padding(.vertical, 4)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "groceries": "cart.fill"
        case "dining": "fork.knife"
        case "transportation": "car.fill"
        case "entertainment": "tv.fill"
        case "shopping": "bag.fill"
        default: "circle.fill"
        }
    }

    private func formatCurrency(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.positivePrefix = amount > 0 ? "+" : ""
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}

// MARK: - Insights Tab

struct InsightsTabView: View {
    @State private var financialManager = FinancialManager.shared
    @State private var selectedAccount: FinancialAccount?
    @State private var recommendations: [BudgetRecommendation] = []
    @State private var anomalies: [TransactionAnomaly] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if selectedAccount != nil {
                    recommendationsSection
                    anomaliesSection
                } else {
                    Text("Select an account")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .onAppear {
            loadInsights()
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget Recommendations")
                .font(.headline)

            if recommendations.isEmpty {
                Text("Your spending looks healthy! No recommendations at this time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(recommendations) { recommendation in
                    RecommendationCard(recommendation: recommendation, currency: selectedAccount?.currency ?? "USD")
                }
            }
        }
    }

    private var anomaliesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unusual Transactions")
                .font(.headline)

            if anomalies.isEmpty {
                Text("No unusual activity detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(anomalies) { anomaly in
                    AnomalyCard(anomaly: anomaly, currency: selectedAccount?.currency ?? "USD")
                }
            }
        }
    }

    private func loadInsights() {
        guard selectedAccount == nil else { return }
        selectedAccount = financialManager.accounts.first

        guard let account = selectedAccount else { return }

        Task {
            // Generate sample recommendations
            recommendations = generateBudgetRecommendations(for: account)
            anomalies = detectAnomalies(for: account)
        }
    }

    private func generateBudgetRecommendations(for account: FinancialAccount) -> [BudgetRecommendation] {
        _ = financialManager.transactions.filter { $0.accountId == account.id }
        let categorySpending = financialManager.getSpendingByCategory()

        var recommendations: [BudgetRecommendation] = []

        for (category, amount) in categorySpending.sorted(by: { $0.value > $1.value }).prefix(3) {
            if amount > 500 {
                recommendations.append(BudgetRecommendation(
                    category: category,
                    reason: "Spending in this category is higher than average",
                    currentSpending: Decimal(amount),
                    recommendedBudget: Decimal(amount * 0.8)
                ))
            }
        }

        return recommendations
    }

    private func detectAnomalies(for account: FinancialAccount) -> [TransactionAnomaly] {
        let accountTransactions = financialManager.transactions.filter { $0.accountId == account.id }
        var anomalies: [TransactionAnomaly] = []

        // Simple anomaly detection: transactions over $1000
        for transaction in accountTransactions where abs(transaction.amount) > 1000 {
            anomalies.append(TransactionAnomaly(
                transaction: transaction,
                reason: "Unusually large transaction amount",
                severity: abs(transaction.amount) > 5000 ? .high : .medium
            ))
        }

        return anomalies
    }
}

private struct RecommendationCard: View {
    let recommendation: BudgetRecommendation
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)

                Text(recommendation.category)
                    .font(.headline)
            }

            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(recommendation.currentSpending, currency: currency))
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(recommendation.recommendedBudget, currency: currency))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.theaPrimary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}

struct AnomalyCard: View {
    let anomaly: TransactionAnomaly
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text(anomaly.transaction.transactionDescription)
                    .font(.headline)
            }

            Text(anomaly.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(anomaly.transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(formatCurrency(Decimal(anomaly.transaction.amount), currency: currency))
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}

// MARK: - Add Account View

struct iOSAddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var financialManager = FinancialManager.shared

    @State private var providerName = ""
    @State private var accountName = ""
    @State private var accountType = "Checking"
    @State private var currency = "USD"

    let accountTypes = ["Checking", "Savings", "Credit Card", "Investment", "Crypto"]
    let currencies = ["USD", "EUR", "GBP", "JPY", "AUD"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    TextField("Provider name (e.g., Chase)", text: $providerName)
                }

                Section("Account Details") {
                    TextField("Account name", text: $accountName)

                    Picker("Account Type", selection: $accountType) {
                        ForEach(accountTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { curr in
                            Text(curr).tag(curr)
                        }
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAccount()
                    }
                    .disabled(providerName.isEmpty || accountName.isEmpty)
                }
            }
        }
    }

    private func addAccount() {
        Task {
            // Map account type string to enum
            let accountTypeEnum: AccountType = switch accountType {
            case "Checking": .checking
            case "Savings": .savings
            case "Credit Card": .credit
            case "Investment": .investment
            case "Crypto": .crypto
            default: .checking
            }

            _ = financialManager.addAccount(
                name: accountName,
                type: accountTypeEnum,
                institution: providerName
            )
            dismiss()
        }
    }
}
