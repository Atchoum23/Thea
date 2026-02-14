import SwiftUI

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

// MARK: - Recommendation Card

struct RecommendationCard: View {
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

// MARK: - Anomaly Card

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
