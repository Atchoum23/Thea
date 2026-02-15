import Charts
import SwiftUI

// MARK: - Tax Estimator View

/// Swiss tax estimation view with canton selection, deduction management,
/// and quarterly payment tracking.
struct TaxEstimatorView: View {
    @State private var taxEstimator = SwissTaxEstimator.shared

    @State private var grossIncome: String = ""
    @State private var selectedCanton: SwissCanton = .geneve
    @State private var filingStatus: FilingStatus = .single
    @State private var childrenCount = 0
    @State private var showingAddDeduction = false
    @State private var estimate: SwissTaxResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                incomeSection
                estimateResultSection
                deductionsSection
                quarterlyPaymentsSection
            }
            .padding()
        }
        .navigationTitle("Tax Estimator")
        .sheet(isPresented: $showingAddDeduction) {
            AddDeductionSheet(taxEstimator: taxEstimator)
        }
    }

    // MARK: - Income Section

    @ViewBuilder
    private var incomeSection: some View {
        GroupBox("Income & Filing") {
            VStack(spacing: 12) {
                HStack {
                    Text("Gross Annual Income (CHF)")
                    Spacer()
                    TextField("e.g. 120000", text: $grossIncome)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                HStack {
                    Text("Canton")
                    Spacer()
                    Picker("Canton", selection: $selectedCanton) {
                        ForEach(SwissCanton.allCases, id: \.self) { canton in
                            Text("\(canton.displayName) (\(canton.rawValue))").tag(canton)
                        }
                    }
                    .frame(maxWidth: 200)
                }

                HStack {
                    Text("Filing Status")
                    Spacer()
                    Picker("Status", selection: $filingStatus) {
                        ForEach(FilingStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                HStack {
                    Text("Children")
                    Spacer()
                    Stepper("\(childrenCount)", value: $childrenCount, in: 0...10)
                        .frame(maxWidth: 120)
                }

                Button("Calculate Estimate") {
                    calculateEstimate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(grossIncome.isEmpty)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Estimate Result

    @ViewBuilder
    private var estimateResultSection: some View {
        if let est = estimate {
            GroupBox("Tax Estimate — \(est.canton.displayName)") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Annual Tax")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("CHF \(est.totalTax, specifier: "%.0f")")
                                .font(.title.bold())
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Effective Rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(est.effectiveRate * 100, specifier: "%.1f")%")
                                .font(.title2.bold())
                        }
                    }

                    Divider()

                    taxBreakdownGrid(est)

                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Quarterly Payment")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("CHF \(est.quarterlyAmount, specifier: "%.0f")")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Marginal Rate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(est.marginalRate * 100, specifier: "%.1f")%")
                                .font(.headline)
                        }
                    }

                    // Tax breakdown chart
                    Chart {
                        SectorMark(angle: .value("Federal", est.federalTax), innerRadius: .ratio(0.6))
                            .foregroundStyle(.red)
                            .annotation(position: .overlay) {
                                if est.totalTax > 0 {
                                    Text("Fed")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                        SectorMark(angle: .value("Cantonal", est.cantonalTax), innerRadius: .ratio(0.6))
                            .foregroundStyle(.orange)
                            .annotation(position: .overlay) {
                                if est.totalTax > 0 {
                                    Text("Canton")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                        SectorMark(angle: .value("Municipal", est.municipalTax), innerRadius: .ratio(0.6))
                            .foregroundStyle(.yellow)
                        SectorMark(angle: .value("Church", est.churchTax), innerRadius: .ratio(0.6))
                            .foregroundStyle(.green)
                    }
                    .frame(height: 200)
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func taxBreakdownGrid(_ est: SwissTaxResult) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            taxLineItem("Federal Tax", est.federalTax, .red)
            taxLineItem("Cantonal Tax", est.cantonalTax, .orange)
            taxLineItem("Municipal Tax", est.municipalTax, .yellow)
            taxLineItem("Church Tax", est.churchTax, .green)
            taxLineItem("Social (AHV/ALV)", est.socialContributions, .blue)
            taxLineItem("Total Deductions", est.deductions, .purple)
        }
    }

    @ViewBuilder
    private func taxLineItem(_ label: String, _ amount: Double, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text("CHF \(amount, specifier: "%.0f")")
                .font(.caption.monospacedDigit())
        }
    }

    // MARK: - Deductions

    @ViewBuilder
    private var deductionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tax Deductions")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingAddDeduction = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }

                if taxEstimator.deductions.isEmpty {
                    Text("No custom deductions. Standard deductions are applied automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(taxEstimator.deductions) { deduction in
                        HStack {
                            Image(systemName: deduction.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(deduction.isActive ? .green : .secondary)
                                .onTapGesture {
                                    taxEstimator.toggleDeduction(id: deduction.id)
                                    recalculate()
                                }

                            VStack(alignment: .leading) {
                                Text(deduction.name)
                                    .font(.subheadline)
                                Text(deduction.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("CHF \(deduction.amount, specifier: "%.0f")")
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Quarterly Payments

    @ViewBuilder
    private var quarterlyPaymentsSection: some View {
        if let est = estimate {
            let schedule = taxEstimator.generateQuarterlySchedule(estimate: est)

            GroupBox("Quarterly Payments") {
                VStack(spacing: 8) {
                    ForEach(schedule) { payment in
                        HStack {
                            Image(systemName: payment.isPaid ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(payment.isPaid ? .green : .secondary)

                            Text("Q\(payment.quarter) \(String(payment.year))")
                                .font(.subheadline.bold())

                            Spacer()

                            Text("CHF \(payment.amount, specifier: "%.0f")")
                                .font(.subheadline.monospacedDigit())

                            if !payment.isPaid {
                                Button("Mark Paid") {
                                    taxEstimator.markQuarterlyPaid(
                                        quarter: payment.quarter,
                                        year: payment.year,
                                        amount: payment.amount
                                    )
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    private func calculateEstimate() {
        guard let income = Double(grossIncome.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "")) else { return }

        estimate = taxEstimator.estimateAnnualTax(
            grossIncome: income,
            canton: selectedCanton,
            filingStatus: filingStatus,
            children: childrenCount
        )
    }

    private func recalculate() {
        if estimate != nil {
            calculateEstimate()
        }
    }
}

// MARK: - Add Deduction Sheet

private struct AddDeductionSheet: View {
    let taxEstimator: SwissTaxEstimator
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var category: DeductionCategory = .other

    var body: some View {
        NavigationStack {
            Form {
                TextField("Deduction Name", text: $name)
                TextField("Amount (CHF)", text: $amount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Picker("Category", selection: $category) {
                    ForEach(DeductionCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
            }
            .navigationTitle("Add Deduction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amt = Double(amount), !name.isEmpty {
                            taxEstimator.addDeduction(TaxDeduction(
                                name: name,
                                amount: amt,
                                category: category
                            ))
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}
