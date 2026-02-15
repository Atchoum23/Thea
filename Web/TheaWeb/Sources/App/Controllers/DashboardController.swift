// DashboardController.swift
// TheaWeb - Dashboard API providing summary data from Thea backend

import Vapor

/// Controller for dashboard data endpoints
struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let dashboard = routes.grouped("dashboard")

        dashboard.get(use: getDashboard)
        dashboard.get("weather", use: getWeather)
        dashboard.get("calendar", use: getCalendar)
        dashboard.get("health", use: getHealth)
        dashboard.get("tasks", use: getTasks)
        dashboard.get("finance", use: getFinance)
        dashboard.get("agents", use: getAgents)
    }

    // MARK: - Full Dashboard

    @Sendable
    func getDashboard(req: Request) async throws -> DashboardResponse {
        _ = try req.auth.require(User.self)
        let theaURL = Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081"

        // Fetch all dashboard sections from Thea backend
        async let weather = fetchSection(type: "weather", theaURL: theaURL, req: req)
        async let calendar = fetchSection(type: "calendar", theaURL: theaURL, req: req)
        async let health = fetchSection(type: "health", theaURL: theaURL, req: req)
        async let tasks = fetchSection(type: "tasks", theaURL: theaURL, req: req)
        async let finance = fetchSection(type: "finance", theaURL: theaURL, req: req)
        async let agents = fetchSection(type: "agents", theaURL: theaURL, req: req)

        return DashboardResponse(
            weather: try await weather,
            calendar: try await calendar,
            health: try await health,
            tasks: try await tasks,
            finance: try await finance,
            agents: try await agents,
            updatedAt: Date()
        )
    }

    // MARK: - Individual Sections

    @Sendable
    func getWeather(req: Request) async throws -> DashboardSection {
        _ = try req.auth.require(User.self)
        return try await fetchSection(
            type: "weather",
            theaURL: Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081",
            req: req
        )
    }

    @Sendable
    func getCalendar(req: Request) async throws -> DashboardSection {
        _ = try req.auth.require(User.self)
        return try await fetchSection(
            type: "calendar",
            theaURL: Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081",
            req: req
        )
    }

    @Sendable
    func getHealth(req: Request) async throws -> DashboardSection {
        _ = try req.auth.require(User.self)
        return try await fetchSection(
            type: "health",
            theaURL: Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081",
            req: req
        )
    }

    @Sendable
    func getTasks(req: Request) async throws -> DashboardSection {
        _ = try req.auth.require(User.self)
        return try await fetchSection(
            type: "tasks",
            theaURL: Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081",
            req: req
        )
    }

    @Sendable
    func getFinance(req: Request) async throws -> DashboardSection {
        _ = try req.auth.require(User.self)
        return try await fetchSection(
            type: "finance",
            theaURL: Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081",
            req: req
        )
    }

    @Sendable
    func getAgents(req: Request) async throws -> DashboardSection {
        _ = try req.auth.require(User.self)
        return try await fetchSection(
            type: "agents",
            theaURL: Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081",
            req: req
        )
    }

    // MARK: - Backend Communication

    private func fetchSection(type: String, theaURL: String, req: Request) async throws -> DashboardSection {
        let uri = URI(string: "\(theaURL)/api/dashboard/\(type)")

        do {
            let response = try await req.client.get(uri)
            if response.status == .ok {
                return try response.content.decode(DashboardSection.self)
            }
        } catch {
            req.logger.warning("Dashboard \(type) fetch failed: \(error)")
        }

        // Return empty section on failure (dashboard is non-critical)
        return DashboardSection(type: type, data: [:], summary: "Not available")
    }
}

// MARK: - Response Types

struct DashboardResponse: Content {
    let weather: DashboardSection
    let calendar: DashboardSection
    let health: DashboardSection
    let tasks: DashboardSection
    let finance: DashboardSection
    let agents: DashboardSection
    let updatedAt: Date
}

struct DashboardSection: Content {
    let type: String
    let data: [String: String]
    let summary: String
}
