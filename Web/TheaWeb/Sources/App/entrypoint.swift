// entrypoint.swift
// TheaWeb - Main entry point for the Vapor application

import Vapor
import Fluent
import FluentSQLiteDriver

@main
struct TheaWebApp {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        defer { Task { try? await app.asyncShutdown() } }

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            throw error
        }
    }
}
