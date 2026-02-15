import Charts
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Financial Dashboard View

// Overview of connected accounts, transactions, and insights

struct FinancialDashboardView: View {
    @State private var financial = FinancialIntegration.shared
    @State private var selectedAccount: ProviderAccount?
    @State private var showingConnectSheet = false
    @State private var isRefreshing = false
    @State private var timeRange: TimeRange = .month

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }

    @State private var selectedTab: FinancialTab = .overview
    @State private var showingImportSheet = false

    enum FinancialTab: String, CaseIterable {
        case overview = "Overview"
        case investments = "Investments"
        case tax = "Tax"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Section", selection: $selectedTab) {
                    ForEach(FinancialTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedTab {
                case .overview:
                    overviewContent
                case .investments:
                    InvestmentPortfolioView()
                case .tax:
                    TaxEstimatorView()
                }
            }
            .navigationTitle("Financial Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingConnectSheet = true }) {
                            Label("Connect Account", systemImage: "plus.circle")
                        }

                        Button(action: { showingImportSheet = true }) {
                            Label("Import Transactions", systemImage: "square.and.arrow.down")
                        }

                        Button(action: { refreshAll() }) {
                            Label("Refresh All", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingConnectSheet) {
                ConnectAccountSheet()
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.commaSeparatedText, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with total balance
                totalBalanceCard

                // Time range picker
                timeRangePicker

                // Accounts grid
                if !financial.connectedAccounts.isEmpty {
                    accountsGrid
                }

                // Recent transactions
                recentTransactionsSection

                // Insights
                insightsSection

                // Budgets
                budgetsSection
            }
            .padding()
        }
        .overlay {
            if financial.connectedAccounts.isEmpty {
                emptyState
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let importer = TransactionImporter.shared
        let accountId = financial.connectedAccounts.first?.id ?? UUID()

        do {
            let ext = url.pathExtension.lowercased()
            if ext == "ofx" || ext == "qfx" {
                _ = try importer.importOFX(from: url, accountId: accountId)
            } else {
                _ = try importer.importCSV(from: url, accountId: accountId)
            }
        } catch {
            // Error logged by TransactionImporter
        }
    }

    // MARK: - Total Balance Card

    private var totalBalanceCard: some View {
        VStack(spacing: 12) {
            Text("Total Balance")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(totalBalanceFormatted)
                .font(.system(size: 48, weight: .bold, design: .rounded))

            if !financial.connectedAccounts.isEmpty {
                Text("\(financial.connectedAccounts.count) accounts connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private var totalBalanceFormatted: String {
        let total = financial.connectedAccounts.reduce(0.0) { $0 + $1.balance }
        return String(format: "$%.2f", total)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Accounts Grid

    private var accountsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(financial.connectedAccounts) { account in
                    AccountCard(account: account)
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)

                Spacer()

                if !recentTransactions.isEmpty {
                    Text("\(recentTransactions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if recentTransactions.isEmpty {
                Text("No transactions found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(recentTransactions.prefix(10)) { transaction in
                        TransactionRow(transaction: transaction, currency: selectedAccount?.currency ?? "USD")
                    }
                }
            }
        }
        .padding()
        .background(Color.controlBackground)
        .cornerRadius(12)
    }

    private var recentTransactions: [Transaction] {
        financial.transactions.sorted { $0.date > $1.date }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.headline)

            if financial.insights.isEmpty {
                Text("No insights available yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(financial.insights) { insight in
                    FinancialInsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color.controlBackground)
        .cornerRadius(12)
    }

    // MARK: - Budgets

    private var budgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budgets")
                .font(.headline)

            if financial.budgets.isEmpty {
                Text("No budgets set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(financial.budgets) { budget in
                    BudgetCard(budget: budget, spent: spentForBudget(budget))
                }
            }
        }
        .padding()
        .background(Color.controlBackground)
        .cornerRadius(12)
    }

    private func spentForBudget(_ budget: Budget) -> Double {
        financial.transactions
            .filter { $0.category == budget.category && $0.amount < 0 }
            .reduce(0.0) { $0 + abs($1.amount) }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Accounts Connected",
            systemImage: "banknote",
            description: Text("Connect your bank accounts or crypto wallets to get started")
        )
    }

    // MARK: - Helper Methods

    private func refreshAll() {
        isRefreshing = true
        Task {
            do {
                try await financial.refreshAllAccounts()
            } catch {
                print("Refresh failed: \(error)")
            }
            isRefreshing = false
        }
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let account: ProviderAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForProvider(account.provider))
                    .foregroundStyle(.blue)

                Spacer()

                Text(account.provider)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            Text(account.name)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatBalance(account.balance, currency: account.currency))
                .font(.title3)
                .fontWeight(.semibold)

            Text("Updated \(account.lastUpdated, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.controlBackground)
        .cornerRadius(12)
    }

    private func iconForProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "revolut": "creditcard"
        case "binance", "coinbase": "bitcoinsign.circle"
        default: "banknote"
        }
    }

    private func formatBalance(_ amount: Double, currency: String) -> String {
        if currency == "USD" || currency == "EUR" {
            String(format: "$%.2f", amount)
        } else {
            String(format: "%.4f %@", amount, currency)
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction
    var currency: String = "USD"

    var body: some View {
        HStack {
            Image(systemName: transaction.amount < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(transaction.amount < 0 ? .red : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.category.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(3)

                    Text(transaction.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatAmount(transaction.amount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(transaction.amount < 0 ? .red : .green)
        }
        .padding(.vertical, 4)
    }

    private func formatAmount(_ amount: Double) -> String {
        let sign = amount >= 0 ? "+" : ""
        return String(format: "%@$%.2f", sign, abs(amount))
    }
}

// MARK: - Financial Insight Card

private struct FinancialInsightCard: View {
    let insight: FinancialInsight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(insight.type))
                .font(.title2)
                .foregroundStyle(colorForType(insight.type))
                .frame(width: 40, height: 40)
                .background(colorForType(insight.type).opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(insight.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.windowBackground)
        .cornerRadius(8)
    }

    private func iconForType(_ type: FinancialInsight.InsightType) -> String {
        switch type {
        case .spendingTrend: "chart.line.uptrend.xyaxis"
        case .categoryAnalysis: "chart.bar"
        case .unusualSpending: "exclamationmark.triangle"
        case .budgetRecommendation: "lightbulb"
        }
    }

    private func colorForType(_ type: FinancialInsight.InsightType) -> Color {
        switch type {
        case .spendingTrend: .green
        case .categoryAnalysis: .orange
        case .unusualSpending: .red
        case .budgetRecommendation: .blue
        }
    }
}

// MARK: - Budget Card

struct BudgetCard: View {
    let budget: Budget
    let spent: Double

    var progress: Double {
        min(spent / budget.limit, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.category.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(progress > 0.9 ? .red : .secondary)
            }

            ProgressView(value: progress)
                .tint(progress > 0.9 ? .red : progress > 0.7 ? .orange : .green)

            HStack {
                Text(String(format: "$%.2f spent", spent))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "of $%.2f", budget.limit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.windowBackground)
        .cornerRadius(8)
    }
}

// MARK: - Connect Account Sheet

struct ConnectAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var financialManager = FinancialManager.shared
    @State private var selectedProvider = "Revolut"
    @State private var accountName = ""
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    let providers = ["Revolut", "Binance", "Coinbase", "Plaid"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(providers, id: \.self) { provider in
                            Text(provider).tag(provider)
                        }
                    }
                }

                Section("Account Details") {
                    TextField("Account Name", text: $accountName)
                        .textContentType(.username)
                }

                Section("Credentials") {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                    SecureField("API Secret", text: $apiSecret)
                        .textContentType(.password)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: connectAccount) {
                        if isConnecting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Connect Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isConnecting || accountName.isEmpty || apiKey.isEmpty)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Connect Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    private func connectAccount() {
        errorMessage = nil
        isConnecting = true

        Task {
            do {
                // Validate credentials
                guard !apiKey.isEmpty else {
                    throw FinancialError.invalidCredentials("API Key is required")
                }

                // Determine account type based on provider
                let accountType: AccountType = switch selectedProvider.lowercased() {
                case "binance", "coinbase":
                    .crypto
                case "plaid":
                    .checking
                default:
                    .checking
                }

                // Create account
                let account = financialManager.addAccount(
                    name: accountName,
                    type: accountType,
                    institution: selectedProvider
                )

                print("✅ Successfully connected account: \(account.name)")

                // Store credentials in Keychain via SecureStorage
                try? SecureStorage.shared.saveAPIKey(apiKey, for: "financial_\(account.id.uuidString)")

                isConnecting = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isConnecting = false
            }
        }
    }
}

#Preview {
    FinancialDashboardView()
}
