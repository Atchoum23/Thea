//
//  AsanaIntegration+Webhooks.swift
//  Thea
//
//  Webhook creation, listing, deletion, and HMAC-SHA256 signature verification
//

import Foundation
import CryptoKit

extension AsanaClient {

    // MARK: - Webhooks

    /// Creates a webhook to receive real-time notifications for resource changes.
    /// - Parameters:
    ///   - resourceGid: The GID of the resource to watch (e.g., a project or task).
    ///   - targetUrl: The HTTPS URL to receive webhook POST requests.
    ///   - filters: Optional array of ``AsanaWebhookFilter`` to restrict which events trigger notifications.
    /// - Returns: The created ``AsanaWebhook`` with its GID and active status.
    public func createWebhook(resourceGid: String, targetUrl: String, filters: [AsanaWebhookFilter]? = nil) async throws -> AsanaWebhook {
        var data: [String: Any] = [
            "resource": resourceGid,
            "target": targetUrl
        ]
        if let filters {
            data["filters"] = filters.map { $0.toDictionary() }
        }

        let response: AsanaDataResponse<AsanaWebhook> = try await request(
            endpoint: "/webhooks",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Retrieves all webhooks in the workspace, optionally filtered by resource.
    /// - Parameters:
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - resourceGid: Optional resource GID to filter webhooks for a specific resource.
    /// - Returns: An array of ``AsanaWebhook`` objects.
    public func getWebhooks(workspaceGid: String? = nil, resourceGid: String? = nil) async throws -> [AsanaWebhook] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var params: [String: String] = ["workspace": workspace]
        if let resourceGid { params["resource"] = resourceGid }

        let response: AsanaDataResponse<[AsanaWebhook]> = try await request(
            endpoint: "/webhooks",
            queryParams: params
        )
        return response.data
    }

    /// Deletes a webhook, stopping all future notifications.
    /// - Parameter webhookGid: The globally unique identifier of the webhook to delete.
    public func deleteWebhook(webhookGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/webhooks/\(webhookGid)",
            method: "DELETE"
        )
    }

    /// Verifies that a webhook payload was sent by Asana using HMAC-SHA256 signature validation.
    ///
    /// Use this to validate incoming webhook requests by comparing the `X-Hook-Signature` header
    /// against a computed HMAC of the request body.
    /// - Parameters:
    ///   - payload: The raw HTTP request body data.
    ///   - signature: The hex-encoded signature from the `X-Hook-Signature` header.
    ///   - secret: The webhook secret obtained during webhook creation handshake.
    /// - Returns: `true` if the signature is valid; `false` otherwise.
    public static func verifyWebhookSignature(payload: Data, signature: String, secret: String) -> Bool {
        let key = SymmetricKey(data: Data(secret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignature = Data(hmac).map { String(format: "%02x", $0) }.joined()
        return computedSignature == signature
    }
}
