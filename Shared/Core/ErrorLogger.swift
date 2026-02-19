// ErrorLogger.swift
// Thea V4 — Structured error logging utility
//
// Provides consistent error logging across the codebase,
// replacing silent `try?` with logged error handling.

import Foundation
import OSLog

// MARK: - Error Logger

/// Centralized error logging with structured OSLog output.
/// Use instead of `try?` when errors should be tracked but not fatal.
enum ErrorLogger {
    private static let logger = Logger(subsystem: "app.thea", category: "ErrorLogger")

    /// Log an error with file/function context
    static func log(
        _ error: Error,
        context: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        logger.error("[\(context)] \(error.localizedDescription) — \(file):\(line) \(function)")
    }

    /// Log a warning (non-error condition that may indicate a problem)
    static func warn(
        _ message: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        logger.warning("\(message) — \(file):\(line) \(function)")
    }

    /// Execute a throwing closure, logging any error and returning nil on failure.
    /// Use as a drop-in replacement for `try?` when you want error visibility.
    static func tryOrNil<T>(
        context: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        _ body: () throws -> T
    ) -> T? {
        do {
            return try body()
        } catch {
            log(error, context: context, file: file, function: function, line: line)
            return nil
        }
    }

    /// Async version of tryOrNil
    static func tryOrNil<T>(
        context: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        _ body: () async throws -> T
    ) async -> T? {
        do {
            return try await body()
        } catch {
            log(error, context: context, file: file, function: function, line: line)
            return nil
        }
    }

    /// Execute a throwing closure, logging any error and returning a default value on failure.
    static func tryOrDefault<T>(
        _ defaultValue: T,
        context: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line,
        _ body: () throws -> T
    ) -> T {
        do {
            return try body()
        } catch {
            log(error, context: context, file: file, function: function, line: line)
            return defaultValue
        }
    }
}
