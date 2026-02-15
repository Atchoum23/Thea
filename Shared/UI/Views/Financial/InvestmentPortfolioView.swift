import Charts
import SwiftUI

// MARK: - Investment Portfolio View

/// Portfolio overview with holdings, performance, asset allocation, and dividends.
struct InvestmentPortfolioView: View {
    @State private var tracker = InvestmentTracker.shared

    @State private var selectedPortfolio: InvestmentPortfolio?
    @State private var showingAddPortfolio = false
    @State private var showingAddHolding = false
    @State private var showingImportCSV = false
    @State private var newPortfolioName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                portfolioSelector
                if let portfolio = selectedPortfolio {
                    performanceSummary(portfolio)
                    assetAllocationChart(portfolio)
                    holdingsList(portfolio)
                    currencyExposure(portfolio)
                    dividendHistory(portfolio)
                } else if tracker.portfolios.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Investments")
        .sheet(isPresented: $showingAddHolding) {
            if let portfolio = selectedPortfolio {
                AddHoldingSheet(tracker: tracker, portfolioId: portfolio.id)
            }
        }
        .alert("New Portfolio", isPresented: $showingAddPortfolio) {
            TextField("Portfolio Name", text: $newPortfolioName)
            Button("Create") {
                if !newPortfolioName.isEmpty {
                    let portfolio = tracker.createPortfolio(name: newPortfolioName)
                    selectedPortfolio = portfolio
                    newPortfolioName = ""
                }
            }
            Button("Cancel", role: .cancel) { newPortfolioName = "" }
        }
    }

    // MARK: - Portfolio Selector

    @ViewBuilder
    private var portfolioSelector: some View {
        HStack {
            if !tracker.portfolios.isEmpty {
                Picker("Portfolio", selection: $selectedPortfolio) {
                    ForEach(tracker.portfolios) { portfolio in
                        Text(portfolio.name).tag(Optional(portfolio))
                    }
                }
            }

            Spacer()

            Button {
                showingAddPortfolio = true
            } label: {
                Label("New Portfolio", systemImage: "plus")
            }
        }
        .onAppear {
            if selectedPortfolio == nil {
                selectedPortfolio = tracker.portfolios.first
            }
        }
    }

    // MARK: - Performance Summary

    @ViewBuilder
    private func performanceSummary(_ portfolio: InvestmentPortfolio) -> some View {
        let perf = tracker.calculatePerformance(portfolioId: portfolio.id)

        GroupBox("Portfolio Performance") {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("Total Value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(portfolio.currency) \(perf.totalValue, specifier: "%.2f")")
                            .font(.title2.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Total Return")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(perf.totalReturn >= 0 ? "+" : "")\(perf.totalReturn * 100, specifier: "%.1f")%")
                            .font(.title2.bold())
                            .foregroundStyle(perf.totalReturn >= 0 ? .green : .red)
                    }
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    metricCard("Cost Basis", "\(portfolio.currency) \(perf.totalCost, specifier: "%.0f")")
                    metricCard("Unrealized P&L", "\(perf.totalGain >= 0 ? "+" : "")\(portfolio.currency) \(perf.totalGain, specifier: "%.0f")")
                    metricCard("Dividends", "\(portfolio.currency) \(perf.totalDividends, specifier: "%.0f")")
                    metricCard("Annualized", "\(perf.annualizedReturn * 100, specifier: "%.1f")%")
                    metricCard("Holdings", "\(perf.holdingCount)")
                    metricCard("Total w/ Divs", "\(perf.totalReturnWithDividends * 100, specifier: "%.1f")%")
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func metricCard(_ label: String, _ value: String) -> some View {
        VStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().bold())
        }
    }

    // MARK: - Asset Allocation Chart

    @ViewBuilder
    private func assetAllocationChart(_ portfolio: InvestmentPortfolio) -> some View {
        let allocation = tracker.calculateAssetAllocation(portfolioId: portfolio.id)

        if !allocation.isEmpty {
            GroupBox("Asset Allocation") {
                Chart(allocation) { item in
                    SectorMark(
                        angle: .value(item.assetClass.displayName, item.value),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value("Class", item.assetClass.displayName))
                    .annotation(position: .overlay) {
                        if item.percentage > 0.05 {
                            Text("\(item.percentage * 100, specifier: "%.0f")%")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 200)
                .padding(.vertical, 8)

                ForEach(allocation) { item in
                    HStack {
                        Image(systemName: item.assetClass.icon)
                            .frame(width: 20)
                        Text(item.assetClass.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.percentage * 100, specifier: "%.1f")%")
                            .font(.subheadline.monospacedDigit())
                        Text("(\(portfolio.currency) \(item.value, specifier: "%.0f"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Holdings List

    @ViewBuilder
    private func holdingsList(_ portfolio: InvestmentPortfolio) -> some View {
        let portfolioHoldings = tracker.holdings.filter { $0.portfolioId == portfolio.id }

        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Holdings")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingAddHolding = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }

                if portfolioHoldings.isEmpty {
                    Text("No holdings yet. Add your first investment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(portfolioHoldings) { holding in
                        holdingRow(holding, currency: portfolio.currency)
                        if holding.id != portfolioHoldings.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func holdingRow(_ holding: Holding, currency: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol)
                    .font(.subheadline.bold())
                Text(holding.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currency) \(holding.currentValue, specifier: "%.0f")")
                    .font(.subheadline.monospacedDigit())

                HStack(spacing: 4) {
                    Image(systemName: holding.returnPercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(holding.returnPercent * 100, specifier: "%.1f")%")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(holding.returnPercent >= 0 ? .green : .red)
            }
        }
    }

    // MARK: - Currency Exposure

    @ViewBuilder
    private func currencyExposure(_ portfolio: InvestmentPortfolio) -> some View {
        let exposure = tracker.calculateCurrencyExposure(portfolioId: portfolio.id)

        if exposure.count > 1 {
            GroupBox("Currency Exposure") {
                ForEach(exposure) { item in
                    HStack {
                        Text(item.currency)
                            .font(.subheadline.bold())

                        ProgressView(value: item.percentage)
                            .tint(item.currency == "CHF" ? .blue : .orange)

                        Text("\(item.percentage * 100, specifier: "%.0f")%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Dividend History

    @ViewBuilder
    private func dividendHistory(_ portfolio: InvestmentPortfolio) -> some View {
        let holdingIds = Set(tracker.holdings.filter { $0.portfolioId == portfolio.id }.map(\.id))
        let dividends = tracker.dividendHistory
            .filter { holdingIds.contains($0.holdingId) }
            .sorted { $0.date > $1.date }

        if !dividends.isEmpty {
            GroupBox("Dividend History") {
                ForEach(dividends.prefix(10)) { div in
                    HStack {
                        let holding = tracker.holdings.first { $0.id == div.holdingId }
                        Text(holding?.symbol ?? "—")
                            .font(.subheadline.bold())
                            .frame(width: 60, alignment: .leading)

                        Text(div.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("\(div.currency) \(div.amount, specifier: "%.2f")")
                                .font(.subheadline.monospacedDigit())
                            if div.taxWithheld > 0 {
                                Text("Tax: \(div.currency) \(div.taxWithheld, specifier: "%.2f")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Portfolios", systemImage: "chart.pie")
        } description: {
            Text("Create your first investment portfolio to track holdings, performance, and dividends.")
        } actions: {
            Button("Create Portfolio") {
                showingAddPortfolio = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Add Holding Sheet

private struct AddHoldingSheet: View {
    let tracker: InvestmentTracker
    let portfolioId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var quantity = ""
    @State private var purchasePrice = ""
    @State private var currency = "CHF"
    @State private var assetClass: AssetClass = .stock

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    TextField("Symbol (e.g. NESN)", text: $symbol)
                    TextField("Name (e.g. Nestlé)", text: $name)
                    Picker("Asset Class", selection: $assetClass) {
                        ForEach(AssetClass.allCases, id: \.self) { cls in
                            Label(cls.displayName, systemImage: cls.icon).tag(cls)
                        }
                    }
                }

                Section("Purchase Details") {
                    TextField("Quantity", text: $quantity)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Purchase Price", text: $purchasePrice)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Picker("Currency", selection: $currency) {
                        Text("CHF").tag("CHF")
                        Text("EUR").tag("EUR")
                        Text("USD").tag("USD")
                        Text("GBP").tag("GBP")
                    }
                }
            }
            .navigationTitle("Add Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHolding()
                    }
                    .disabled(symbol.isEmpty || quantity.isEmpty || purchasePrice.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func addHolding() {
        guard let qty = Double(quantity),
              let price = Double(purchasePrice.replacingOccurrences(of: "'", with: "")) else { return }

        _ = tracker.addHolding(
            portfolioId: portfolioId,
            symbol: symbol,
            name: name.isEmpty ? symbol : name,
            quantity: qty,
            purchasePrice: price,
            purchaseDate: Date(),
            currency: currency,
            assetClass: assetClass
        )
        dismiss()
    }
}
