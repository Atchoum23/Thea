// ExternalSubscriptionsView.swift
// Thea — External subscription tracking UI
//
// Track and manage third-party subscriptions (Netflix, Spotify,
// AWS, etc.) with cost analytics and renewal reminders.

import SwiftUI

struct ExternalSubscriptionsView: View {
    @ObservedObject private var manager = ExternalSubscriptionManager.shared
    @State private var showingAddSub = false
    @State private var searchText = ""

    var body: some View {
        List {
            overviewSection
            renewingSoonSection
            activeSubscriptionsSection
            costBreakdownSection
        }
        .navigationTitle("Subscriptions")
        .searchable(text: $searchText, prompt: "Search subscriptions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSub = true } label: {
                    Label("Add Subscription", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSub) {
            AddSubscriptionSheet { sub in
                manager.addSubscription(sub)
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section {
            HStack {
                SubStatCard(label: "Active", value: "\(manager.activeSubscriptions.count)",
                            icon: "creditcard", color: .blue)
                SubStatCard(label: "Monthly", value: String(format: "CHF %.0f", manager.totalMonthlyCost),
                            icon: "calendar", color: .green)
                SubStatCard(label: "Annual", value: String(format: "CHF %.0f", manager.totalAnnualCost),
                            icon: "chart.bar", color: .purple)
            }
        } header: {
            Text("Overview")
        }
    }

    @ViewBuilder
    private var renewingSoonSection: some View {
        let renewing = manager.renewingSoon
        if !renewing.isEmpty {
            Section {
                ForEach(renewing) { sub in
                    subscriptionRow(sub, highlight: true)
                }
            } header: {
                Text("Renewing Soon")
            }
        }
    }

    private var activeSubscriptionsSection: some View {
        Section {
            let subs = filteredSubscriptions
            if subs.isEmpty {
                ContentUnavailableView("No Subscriptions", systemImage: "creditcard",
                                       description: Text("Add subscriptions to track your spending."))
            } else {
                ForEach(subs) { sub in
                    subscriptionRow(sub)
                }
                .onDelete { offsets in
                    for idx in offsets {
                        manager.deleteSubscription(id: subs[idx].id)
                    }
                }
            }
        } header: {
            Text("All Subscriptions")
        }
    }

    @ViewBuilder
    private var costBreakdownSection: some View {
        let categories = manager.costByCategory
        if !categories.isEmpty {
            Section {
                ForEach(categories, id: \.category) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(item.category.displayName)
                        Spacer()
                        Text(String(format: "CHF %.0f/mo", item.monthly))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Cost by Category")
            }
        }
    }

    // MARK: - Row

    private func subscriptionRow(_ sub: ExternalSubscription, highlight: Bool = false) -> some View {
        HStack {
            Image(systemName: sub.category.icon)
                .foregroundStyle(highlight ? Color.orange : Color.theaAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.body)
                HStack(spacing: 4) {
                    Text(sub.billingCycle.displayName)
                    Text("·")
                    Text(sub.category.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if highlight {
                    Text("Renews \(sub.nextRenewalDate, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(sub.currency) \(sub.cost, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("/\(sub.billingCycle.displayName.lowercased())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Filter

    private var filteredSubscriptions: [ExternalSubscription] {
        let active = manager.activeSubscriptions
        if searchText.isEmpty { return active }
        let q = searchText.lowercased()
        return active.filter { $0.name.lowercased().contains(q) || $0.category.displayName.lowercased().contains(q) }
    }
}

// MARK: - Add Subscription Sheet

private struct AddSubscriptionSheet: View {
    let onSave: (ExternalSubscription) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cost = ""
    @State private var category: SubscriptionCategory = .streaming
    @State private var billingCycle: BillingCycle = .monthly
    @State private var currency = "CHF"

    var body: some View {
        NavigationStack {
            Form {
                Section("Subscription") {
                    TextField("Name (e.g., Netflix)", text: $name)
                    TextField("Cost", text: $cost)
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
                Section("Details") {
                    Picker("Category", selection: $category) {
                        ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Billing Cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.displayName).tag(cycle)
                        }
                    }
                }
            }
            .navigationTitle("Add Subscription")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let sub = ExternalSubscription(
                            name: name, category: category,
                            cost: Double(cost) ?? 0, currency: currency,
                            billingCycle: billingCycle
                        )
                        onSave(sub)
                        dismiss()
                    }
                    .disabled(name.isEmpty || cost.isEmpty)
                }
            }
        }
    }
}

// MARK: - Sub Stat Card

private struct SubStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
