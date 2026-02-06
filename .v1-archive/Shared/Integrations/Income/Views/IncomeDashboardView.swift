import SwiftUI

/// Income tracking dashboard
public struct IncomeDashboardView: View {
    @State private var viewModel = IncomeViewModel()
    @State private var showingStreamEditor = false
    @State private var showingEntryLogger = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    summarySection

                    // Active Streams
                    activeStreamsSection

                    // Category Breakdown
                    if !viewModel.categoryBreakdown.isEmpty {
                        categoryBreakdownSection
                    }

                    // Recent Entries
                    if !viewModel.recentEntries.isEmpty {
                        recentEntriesSection
                    }

                    // Tax Estimate
                    if let tax = viewModel.taxEstimate {
                        taxEstimateSection(tax)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Income")
            .toolbar {
                Menu {
                    Button {
                        showingStreamEditor = true
                    } label: {
                        Label("Add Stream", systemImage: "plus.circle")
                    }

                    Button {
                        showingEntryLogger = true
                    } label: {
                        Label("Log Income", systemImage: "dollarsign.circle")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingStreamEditor) {
                StreamEditorView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEntryLogger) {
                EntryLoggerView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Monthly Income",
                value: "$\(Int(viewModel.totalMonthlyIncome))",
                icon: "dollarsign.circle.fill",
                color: .green
            )

            SummaryCard(
                title: "Active Streams",
                value: "\(viewModel.activeStreamsCount)",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )

            SummaryCard(
                title: "Annual Projection",
                value: "$\(Int(viewModel.totalAnnualProjection))",
                icon: "calendar",
                color: .purple
            )

            SummaryCard(
                title: "Passive Income",
                value: "\(Int(viewModel.passiveIncomePercentage))%",
                icon: "chart.pie.fill",
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Active Streams Section

    private var activeStreamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Streams")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.streams.filter(\.isActive).isEmpty {
                Text("No active streams")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.streams.filter(\.isActive)) { stream in
                    StreamCard(stream: stream)
                }
            }
        }
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income by Category")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.categoryBreakdown, id: \.0) { category, amount in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(.blue)

                    Text(category.rawValue)
                        .font(.subheadline)

                    Spacer()

                    Text("$\(Int(amount))/mo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Entries Section

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Income")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.recentEntries.prefix(5)) { entry in
                EntryRow(entry: entry, streams: viewModel.streams)
            }
        }
    }

    // MARK: - Tax Estimate Section

    private func taxEstimateSection(_ tax: TaxEstimate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Estimate (\(tax.year))")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Gross Income:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(Int(tax.grossIncome))")
                }

                Divider()

                HStack {
                    Text("Federal Tax:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(Int(tax.estimatedFederalTax))")
                }

                HStack {
                    Text("State Tax:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(Int(tax.estimatedStateTax))")
                }

                HStack {
                    Text("Self-Employment:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(Int(tax.estimatedSelfEmploymentTax))")
                }

                Divider()

                HStack {
                    Text("Total Tax:")
                        .font(.headline)
                    Spacer()
                    Text("$\(Int(tax.totalTax))")
                        .font(.headline)
                }

                HStack {
                    Text("Quarterly Payment:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(Int(tax.quarterlyPaymentDue))")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Text("Effective Rate:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", tax.effectiveTaxRate))%")
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .bold()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stream Card

private struct StreamCard: View {
    let stream: IncomeStream

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stream.category.icon)
                    .foregroundStyle(.blue)

                Text(stream.name)
                    .font(.headline)

                Spacer()

                Text("$\(Int(stream.monthlyAmount))/mo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(stream.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(typeColor(stream.type).opacity(0.2))
                    .foregroundStyle(typeColor(stream.type))
                    .clipShape(Capsule())

                Text(stream.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("$\(Int(stream.annualProjection))/yr")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = stream.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func typeColor(_ type: IncomeType) -> Color {
        switch type {
        case .passive: .green
        case .active: .blue
        case .portfolio: .purple
        }
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: IncomeEntry
    let streams: [IncomeStream]

    private var streamName: String {
        streams.first { $0.id == entry.streamID }?.name ?? "Unknown"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(streamName)
                    .font(.subheadline)

                if let description = entry.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.receivedDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("$\(Int(entry.netAmount))")
                .font(.subheadline)
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - Stream Editor View

private struct StreamEditorView: View {
    @Bindable var viewModel: IncomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: IncomeType = .active
    @State private var category: IncomeCategory = .freelancing
    @State private var monthlyAmount = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Stream Details") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(IncomeType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Picker("Category", selection: $category) {
                        ForEach(IncomeCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    TextField("Monthly Amount", text: $monthlyAmount)
                }

                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
                }
            }
            .navigationTitle("New Income Stream")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = Double(monthlyAmount) {
                            let stream = IncomeStream(
                                name: name,
                                type: type,
                                category: category,
                                monthlyAmount: amount,
                                notes: notes.isEmpty ? nil : notes
                            )

                            Task {
                                await viewModel.addStream(stream)
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.isEmpty || monthlyAmount.isEmpty)
                }
            }
        }
    }
}

// MARK: - Entry Logger View

private struct EntryLoggerView: View {
    @Bindable var viewModel: IncomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStream: IncomeStream?
    @State private var amount = ""
    @State private var receivedDate = Date()
    @State private var entryDescription = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Income Details") {
                    Picker("Stream", selection: $selectedStream) {
                        Text("Select stream...").tag(nil as IncomeStream?)
                        ForEach(viewModel.streams.filter(\.isActive)) { stream in
                            Text(stream.name).tag(stream as IncomeStream?)
                        }
                    }

                    TextField("Amount", text: $amount)

                    DatePicker("Received Date", selection: $receivedDate, displayedComponents: .date)
                }

                Section("Description") {
                    TextField("Optional description...", text: $entryDescription)
                }
            }
            .navigationTitle("Log Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let stream = selectedStream, let amountValue = Double(amount) {
                            Task {
                                await viewModel.addEntry(
                                    streamID: stream.id,
                                    amount: amountValue,
                                    receivedDate: receivedDate,
                                    description: entryDescription.isEmpty ? nil : entryDescription
                                )
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedStream == nil || amount.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    IncomeDashboardView()
}
