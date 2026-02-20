// YNABService.swift
// Thea — Financial Intelligence Hub (AAC3-5)
//
// Swift actor wrapping andrebocchini/swiftynab for YNAB budget integration.
// Uses delta sync via `lastKnowledgeOfServer` to fetch only changed data.
// Credentials: YNAB personal access token in Keychain via FinancialCredentialStore.

import Foundation
import SwiftYNAB
import OSLog

// MARK: - YNAB Budget Summary Model

struct YNABBudgetSummary: Sendable {
    let id: String
    let name: String
    let lastModifiedOn: String?
    let firstMonth: String?
    let lastMonth: String?
}

// MARK: - YNAB Transaction Summary

struct YNABTransaction: Sendable {
    let id: String
    let date: String           // ISO date e.g. "2024-03-15"
    let amount: Int            // Milliunits (divide by 1000 for actual value)
    let memo: String?
    let cleared: String
    let approved: Bool
    let accountName: String
    let payeeName: String?
    let categoryName: String?
}

// MARK: - YNABService

actor YNABService {
    static let shared = YNABService()

    private let logger = Logger(subsystem: "com.thea.app", category: "YNABService")

    /// Persisted server knowledge per budget for delta sync.
    /// Key: budgetID, Value: lastKnowledgeOfServer (Int)
    private var serverKnowledgeCache: [String: Int] = [:]

    private var client: YNAB? {
        guard
            let token = FinancialCredentialStore.load(provider: .ynab),
            !token.isEmpty
        else { return nil }
        return YNAB(accessToken: token)
    }

    private init() {}

    // MARK: - Credential Management

    /// Store YNAB personal access token in Keychain.
    func saveAccessToken(_ token: String) {
        FinancialCredentialStore.save(token: token, provider: .ynab)
        logger.info("YNABService: access token saved")
    }

    /// Whether a YNAB token is stored.
    func hasCredentials() -> Bool {
        FinancialCredentialStore.hasCredentials(for: .ynab)
    }

    // MARK: - Fetch Budget Summaries

    /// Fetch all YNAB budgets for the authenticated user.
    func fetchBudgetSummaries() async throws -> [YNABBudgetSummary] {
        guard let ynab = client else {
            throw YNABServiceError.missingCredentials
        }

        let budgets = try await ynab.budgets.budgets(includeAccounts: false)
        return budgets.map {
            YNABBudgetSummary(
                id:             $0.id,
                name:           $0.name,
                lastModifiedOn: $0.lastModifiedOn,
                firstMonth:     $0.firstMonth,
                lastMonth:      $0.lastMonth
            )
        }
    }

    // MARK: - Fetch Transactions (Delta Sync)

    /// Fetch transactions for a budget using delta sync.
    /// Only fetches changes since the last sync (via `lastKnowledgeOfServer`).
    /// - Parameter budgetID: YNAB budget ID (use "last-used" for the most recently opened budget)
    /// - Returns: New/changed transactions since last sync.
    func fetchBudgetSummary(budgetID: String = "last-used") async throws -> [YNABTransaction] {
        guard let ynab = client else {
            throw YNABServiceError.missingCredentials
        }

        let lastKnowledge = serverKnowledgeCache[budgetID]

        let (transactions, newKnowledge) = try await ynab.transactions.transactions(
            budgetId: budgetID,
            lastKnowledgeOfServer: lastKnowledge
        )

        // Persist new server knowledge for next delta sync
        serverKnowledgeCache[budgetID] = newKnowledge
        logger.debug("YNABService: fetched \(transactions.count) transactions, knowledge: \(newKnowledge)")

        return transactions.map { tx in
            YNABTransaction(
                id:           tx.id,
                date:         tx.date,
                amount:       tx.amount,
                memo:         tx.memo,
                cleared:      tx.cleared.rawValue,
                approved:     tx.approved,
                accountName:  tx.accountName ?? "",
                payeeName:    tx.payeeName,
                categoryName: tx.categoryName
            )
        }
    }

    // MARK: - Reset Delta Sync

    /// Clear cached server knowledge, forcing a full sync on the next call.
    func resetDeltaSync(for budgetID: String? = nil) {
        if let id = budgetID {
            serverKnowledgeCache.removeValue(forKey: id)
        } else {
            serverKnowledgeCache.removeAll()
        }
        logger.info("YNABService: delta sync cache cleared")
    }
}

// MARK: - Error

enum YNABServiceError: LocalizedError {
    case missingCredentials
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "YNAB access token not configured. Please add it in Settings → Financial."
        case .apiError(let msg):  return "YNAB API error: \(msg)"
        }
    }
}
