// YNABService.swift
// Thea — Financial Intelligence Hub (AAC3-5)
//
// Swift actor for YNAB (You Need A Budget) REST API v1.
// Uses URLSession — no SPM dependency (swiftynab 1.x uses callback API, not async/await).
// Uses delta sync via `last_knowledge_of_server` to fetch only changed transactions.
// Credentials: YNAB personal access token in Keychain via FinancialCredentialStore.

import Foundation
import OSLog

// MARK: - YNAB Budget Summary Model

struct YNABBudgetSummary: Sendable {
    let id: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let name: String
    let lastModifiedOn: String? // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let firstMonth: String? // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let lastMonth: String? // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
}

// MARK: - YNAB Transaction

// periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
struct YNABTransaction: Sendable {
    let id: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let date: String            // ISO date e.g. "2024-03-15"
    let amount: Int             // Milliunits (divide by 1000 for real value)
    let memo: String?
    let cleared: String
    let approved: Bool
    let accountName: String
    let payeeName: String?
    let categoryName: String?
    let deleted: Bool
}

// MARK: - YNABService

actor YNABService {
    static let shared = YNABService()

    private let logger = Logger(subsystem: "com.thea.app", category: "YNABService") // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    private let baseURL = URL(string: "https://api.youneedabudget.com/v1")!

    /// Server knowledge per budget for delta sync. Key: budgetID, Value: Int knowledge
    private var serverKnowledgeCache: [String: Int] = [:]

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
        let data = try await get(path: "/budgets?include_accounts=false")
        let json = try parseYNABResponse(data)
        guard let budgetsArray = json["budgets"] as? [[String: Any]] else { return [] }
        return budgetsArray.compactMap { dict -> YNABBudgetSummary? in
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            return YNABBudgetSummary(
                id: id,
                name: name,
                lastModifiedOn: dict["last_modified_on"] as? String,
                firstMonth: dict["first_month"] as? String,
                lastMonth: dict["last_month"] as? String
            )
        }
    }

    // MARK: - Fetch Transactions (Delta Sync)

    /// Fetch transactions for a budget using delta sync.
    /// Pass `budgetID: "last-used"` to use the most recently opened budget.
    /// - Returns: New/changed transactions since last sync.
    func fetchBudgetSummary(budgetID: String = "last-used") async throws -> [YNABTransaction] {
        var path = "/budgets/\(budgetID)/transactions"
        if let lastKnowledge = serverKnowledgeCache[budgetID] {
            path += "?last_knowledge_of_server=\(lastKnowledge)"
        }

        let data = try await get(path: path)
        let json = try parseYNABResponse(data)

        guard let wrapper = json["transactions"] as? [String: Any] else {
            // Might be direct array (depends on YNAB response format)
            if let txArray = json["transactions"] as? [[String: Any]] {
                let serverKnowledge = json["server_knowledge"] as? Int
                if let sk = serverKnowledge { serverKnowledgeCache[budgetID] = sk }
                return txArray.compactMap { parseTransaction($0) }
            }
            return []
        }
        _ = wrapper // silence unused warning

        let serverKnowledge = json["server_knowledge"] as? Int
        if let sk = serverKnowledge { serverKnowledgeCache[budgetID] = sk }

        let txArray = json["transactions"] as? [[String: Any]] ?? []
        logger.debug("YNABService: \(txArray.count) transactions, knowledge: \(serverKnowledge ?? 0)")
        return txArray.compactMap { parseTransaction($0) }
    }

    // MARK: - Reset Delta Sync

    func resetDeltaSync(for budgetID: String? = nil) {
        if let id = budgetID { serverKnowledgeCache.removeValue(forKey: id) } else { serverKnowledgeCache.removeAll() }
        logger.info("YNABService: delta sync cache cleared")
    }

    // MARK: - HTTP Layer

    private func get(path: String) async throws -> Data {
        guard let token = FinancialCredentialStore.load(provider: .ynab), !token.isEmpty else {
            throw YNABServiceError.missingCredentials
        }
        let url = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw YNABServiceError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw YNABServiceError.httpError(http.statusCode) }
        return data
    }

    private func parseYNABResponse(_ data: Data) throws -> [String: Any] {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let errorObj = root["error"] as? [String: Any],
           let detail = errorObj["detail"] as? String {
            throw YNABServiceError.apiError(detail)
        }
        return (root["data"] as? [String: Any]) ?? root
    }

    private func parseTransaction(_ dict: [String: Any]) -> YNABTransaction? {
        guard
            let id   = dict["id"]   as? String,
            let date = dict["date"] as? String
        else { return nil }
        return YNABTransaction(
            id: id,
            date: date,
            amount: dict["amount"]       as? Int    ?? 0,
            memo: dict["memo"]         as? String,
            cleared: dict["cleared"]      as? String ?? "uncleared",
            approved: dict["approved"]     as? Bool   ?? false,
            accountName: dict["account_name"] as? String ?? "",
            payeeName: dict["payee_name"]   as? String,
            categoryName: dict["category_name"] as? String,
            deleted: dict["deleted"]      as? Bool   ?? false
        )
    }
}

// MARK: - Error

enum YNABServiceError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:   return "YNAB access token not configured. Please add it in Settings → Financial."
        case .invalidResponse:      return "YNAB returned an invalid response."
        case .httpError(let code):  return "YNAB HTTP error \(code)."
        case .apiError(let msg):    return "YNAB API error: \(msg)"
        }
    }
}
