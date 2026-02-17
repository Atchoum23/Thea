//
//  AsanaIntegration+Portfolios.swift
//  Thea
//
//  Portfolio CRUD, item management, custom fields, members, and portfolio memberships
//

import Foundation

extension AsanaClient {

    // MARK: - Portfolios

    /// Retrieves portfolios in the workspace owned by the specified user.
    /// - Parameters:
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - owner: The owner filter; defaults to `"me"` for the authenticated user.
    /// - Returns: An array of ``AsanaPortfolio`` objects.
    public func getPortfolios(workspaceGid: String? = nil, owner: String = "me") async throws -> [AsanaPortfolio] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        let response: AsanaDataResponse<[AsanaPortfolio]> = try await request(
            endpoint: "/portfolios",
            queryParams: [
                "workspace": workspace,
                "owner": owner,
                "opt_fields": "name,color,created_at,created_by,custom_field_settings"
            ]
        )
        return response.data
    }

    /// Retrieves a specific portfolio by its GID.
    /// - Parameter gid: The globally unique identifier of the portfolio.
    /// - Returns: The ``AsanaPortfolio`` with full details including members and owner.
    public func getPortfolio(gid: String) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(gid)",
            queryParams: ["opt_fields": "name,color,created_at,created_by,custom_field_settings,members,owner"]
        )
        return response.data
    }

    /// Creates a new portfolio in the specified workspace.
    /// - Parameters:
    ///   - name: The name for the new portfolio.
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - color: Optional color for the portfolio (e.g., `"dark-pink"`, `"light-green"`).
    ///   - owner: Optional owner GID; defaults to the authenticated user.
    /// - Returns: The newly created ``AsanaPortfolio``.
    public func createPortfolio(
        name: String,
        workspaceGid: String? = nil,
        color: String? = nil,
        owner: String? = nil
    ) async throws -> AsanaPortfolio {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var data: [String: Any] = ["name": name, "workspace": workspace]
        if let color { data["color"] = color }
        if let owner { data["owner"] = owner }

        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Updates an existing portfolio with the provided field values.
    /// - Parameters:
    ///   - gid: The globally unique identifier of the portfolio to update.
    ///   - updates: A dictionary of field names to new values.
    /// - Returns: The updated ``AsanaPortfolio``.
    public func updatePortfolio(gid: String, updates: [String: Any]) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(gid)",
            method: "PUT",
            body: ["data": updates]
        )
        return response.data
    }

    /// Permanently deletes a portfolio.
    /// - Parameter gid: The globally unique identifier of the portfolio to delete.
    public func deletePortfolio(gid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(gid)",
            method: "DELETE"
        )
    }

    /// Retrieves the projects (items) contained in a portfolio.
    /// - Parameter portfolioGid: The globally unique identifier of the portfolio.
    /// - Returns: An array of ``AsanaProject`` objects in the portfolio.
    public func getPortfolioItems(portfolioGid: String) async throws -> [AsanaProject] {
        let response: AsanaDataResponse<[AsanaProject]> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/items",
            queryParams: ["opt_fields": "name,notes,color,archived,due_on,current_status"]
        )
        return response.data
    }

    /// Adds a project to a portfolio with optional ordering.
    /// - Parameters:
    ///   - portfolioGid: The globally unique identifier of the portfolio.
    ///   - itemGid: The GID of the project to add.
    ///   - insertBefore: Optional GID of an existing item to insert before.
    ///   - insertAfter: Optional GID of an existing item to insert after.
    public func addItemToPortfolio(portfolioGid: String, itemGid: String, insertBefore: String? = nil, insertAfter: String? = nil) async throws {
        var data: [String: Any] = ["item": itemGid]
        if let insertBefore { data["insert_before"] = insertBefore }
        if let insertAfter { data["insert_after"] = insertAfter }

        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(portfolioGid)/addItem",
            method: "POST",
            body: ["data": data]
        )
    }

    /// Removes a project from a portfolio.
    /// - Parameters:
    ///   - portfolioGid: The globally unique identifier of the portfolio.
    ///   - itemGid: The GID of the project to remove.
    public func removeItemFromPortfolio(portfolioGid: String, itemGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(portfolioGid)/removeItem",
            method: "POST",
            body: ["data": ["item": itemGid]]
        )
    }

    /// Adds a custom field setting to a portfolio.
    /// - Parameters:
    ///   - portfolioGid: The globally unique identifier of the portfolio.
    ///   - customFieldGid: The GID of the custom field to add.
    ///   - isImportant: Whether the field should be marked as important.
    ///   - insertBefore: Optional GID of an existing custom field to insert before.
    ///   - insertAfter: Optional GID of an existing custom field to insert after.
    /// - Returns: The ``AsanaCustomFieldSetting`` that was created.
    public func addCustomFieldToPortfolio(portfolioGid: String, customFieldGid: String, isImportant: Bool = false, insertBefore: String? = nil, insertAfter: String? = nil) async throws -> AsanaCustomFieldSetting {
        var data: [String: Any] = ["custom_field": customFieldGid, "is_important": isImportant]
        if let insertBefore { data["insert_before"] = insertBefore }
        if let insertAfter { data["insert_after"] = insertAfter }

        let response: AsanaDataResponse<AsanaCustomFieldSetting> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/addCustomFieldSetting",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Removes a custom field setting from a portfolio.
    /// - Parameters:
    ///   - portfolioGid: The globally unique identifier of the portfolio.
    ///   - customFieldGid: The GID of the custom field to remove.
    public func removeCustomFieldFromPortfolio(portfolioGid: String, customFieldGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(portfolioGid)/removeCustomFieldSetting",
            method: "POST",
            body: ["data": ["custom_field": customFieldGid]]
        )
    }

    /// Adds members to a portfolio.
    /// - Parameters:
    ///   - portfolioGid: The globally unique identifier of the portfolio.
    ///   - members: An array of user GIDs or email addresses to add.
    /// - Returns: The updated ``AsanaPortfolio`` with the new members.
    public func addMembersToPortfolio(portfolioGid: String, members: [String]) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/addMembers",
            method: "POST",
            body: ["data": ["members": members]]
        )
        return response.data
    }

    /// Removes members from a portfolio.
    /// - Parameters:
    ///   - portfolioGid: The globally unique identifier of the portfolio.
    ///   - members: An array of user GIDs or email addresses to remove.
    /// - Returns: The updated ``AsanaPortfolio`` without the removed members.
    public func removeMembersFromPortfolio(portfolioGid: String, members: [String]) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/removeMembers",
            method: "POST",
            body: ["data": ["members": members]]
        )
        return response.data
    }

    // MARK: - Portfolio Memberships

    /// Retrieves all memberships for a portfolio.
    /// - Parameter portfolioGid: The globally unique identifier of the portfolio.
    /// - Returns: An array of ``AsanaPortfolioMembership`` objects.
    public func getPortfolioMemberships(portfolioGid: String) async throws -> [AsanaPortfolioMembership] {
        let response: AsanaDataResponse<[AsanaPortfolioMembership]> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/portfolio_memberships",
            queryParams: ["opt_fields": "user,portfolio"]
        )
        return response.data
    }

    /// Retrieves a specific portfolio membership by its GID.
    /// - Parameter gid: The globally unique identifier of the portfolio membership.
    /// - Returns: The ``AsanaPortfolioMembership`` with user and portfolio details.
    public func getPortfolioMembership(gid: String) async throws -> AsanaPortfolioMembership {
        let response: AsanaDataResponse<AsanaPortfolioMembership> = try await request(
            endpoint: "/portfolio_memberships/\(gid)",
            queryParams: ["opt_fields": "user,portfolio"]
        )
        return response.data
    }
}
