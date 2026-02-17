//
//  SubscriptionSettingsView.swift
//  Thea
//
//  Subscription management and paywall UI.
//  Shows current tier, available plans, purchase flow, and subscription management.
//

import StoreKit
import SwiftUI

// MARK: - Subscription Settings View

struct SubscriptionSettingsView: View {
    @ObservedObject private var store = StoreKitService.shared
    @State private var showRestoreAlert = false
    @State private var restoreError: String?
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                currentPlanSection
                tierComparisonSection
                if !store.subscriptionProducts.isEmpty {
                    subscriptionProductsSection
                }
                if !store.nonConsumableProducts.isEmpty {
                    addonsSection
                }
                managementSection
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK") {}
        } message: {
            if let error = restoreError {
                Text("Failed to restore: \(error)")
            } else {
                Text("Purchases restored successfully.")
            }
        }
    }

    // MARK: - Current Plan

    private var currentPlanSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Current Plan")
                            .font(.headline)
                        SubscriptionBadge()
                    }
                    Text(store.subscriptionStatus.displayName)
                        .font(.title2.bold())
                    Text(FeatureGate.currentTier.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                tierIcon
            }
            .padding()
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if case let .pro(expiresAt) = store.subscriptionStatus {
                expirationBanner(date: expiresAt)
            } else if case let .team(expiresAt) = store.subscriptionStatus {
                expirationBanner(date: expiresAt)
            } else if case let .expired(expiredAt) = store.subscriptionStatus {
                expiredBanner(date: expiredAt)
            }
        }
    }

    private var tierIcon: some View {
        Image(systemName: tierIconName)
            .font(.system(size: 40))
            .foregroundStyle(tierColor)
    }

    private var tierIconName: String {
        switch FeatureGate.currentTier {
        case .free: "person.circle"
        case .pro: "star.circle.fill"
        case .team: "person.3.fill"
        }
    }

    private var tierColor: Color {
        switch FeatureGate.currentTier {
        case .free: .secondary
        case .pro: .purple
        case .team: .blue
        }
    }

    private func expirationBanner(date: Date) -> some View {
        HStack {
            Image(systemName: "calendar")
            Text("Renews \(date, style: .date)")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func expiredBanner(date: Date) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.theaWarning)
            Text("Expired \(date, style: .date). Renew to restore Pro features.")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.theaWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Tier Comparison

    private var tierComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare Plans")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                ForEach(SubscriptionTier.allCases, id: \.rawValue) { tier in
                    tierCard(tier)
                }
            }
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tier.rawValue)
                    .font(.headline)
                if tier == FeatureGate.currentTier {
                    Text("Current")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.theaSuccess, in: Capsule())
                }
            }

            Text(tier.monthlyPrice)
                .font(.title3.bold())
                .foregroundStyle(tier == .free ? .secondary : .primary)

            if tier != .free {
                Text(tier.annualPrice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(tier.features, id: \.rawValue) { feature in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.theaSuccess)
                        Text(feature.rawValue)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tier == FeatureGate.currentTier
            ? Color.accentColor.opacity(0.08)
            : Color.clear
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    tier == FeatureGate.currentTier
                    ? Color.accentColor
                    : Color.secondary.opacity(0.2),
                    lineWidth: tier == FeatureGate.currentTier ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subscription Products

    private var subscriptionProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Subscriptions")
                .font(.headline)

            ForEach(store.subscriptionProducts, id: \.id) { product in
                subscriptionRow(product)
            }
        }
    }

    private func subscriptionRow(_ product: Product) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.body)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProductPurchaseButton(product: product)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Add-ons

    private var addonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add-ons")
                .font(.headline)

            ForEach(store.nonConsumableProducts, id: \.id) { product in
                subscriptionRow(product)
            }
        }
    }

    // MARK: - Management

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    Task {
                        isRestoring = true
                        defer { isRestoring = false }
                        do {
                            try await store.restorePurchases()
                            restoreError = nil
                            showRestoreAlert = true
                        } catch {
                            restoreError = error.localizedDescription
                            showRestoreAlert = true
                        }
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRestoring)

                #if os(iOS)
                Button {
                    Task {
                        await store.showManageSubscription()
                    }
                } label: {
                    Label("Manage Subscription", systemImage: "gear")
                }
                #endif

                Spacer()
            }
            .padding()
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if store.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading products...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = store.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.theaWarning)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period. Manage in Settings > Apple ID > Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
