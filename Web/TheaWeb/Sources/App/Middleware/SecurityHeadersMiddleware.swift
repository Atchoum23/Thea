// SecurityHeadersMiddleware.swift
// TheaWeb - Security headers middleware for OWASP compliance

import Vapor

/// Middleware that adds security headers to all responses
/// Implements OWASP recommendations for web security
struct SecurityHeadersMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)

        // Prevent clickjacking
        response.headers.add(name: "X-Frame-Options", value: "DENY")

        // Prevent MIME type sniffing
        response.headers.add(name: "X-Content-Type-Options", value: "nosniff")

        // XSS Protection (legacy browsers)
        response.headers.add(name: "X-XSS-Protection", value: "1; mode=block")

        // Referrer Policy - don't leak URL paths
        response.headers.add(name: "Referrer-Policy", value: "strict-origin-when-cross-origin")

        // Permissions Policy - restrict browser features
        response.headers.add(
            name: "Permissions-Policy",
            value: "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
        )

        // Content Security Policy
        if request.application.environment == .production {
            response.headers.add(
                name: "Content-Security-Policy",
                value: """
                default-src 'self'; \
                script-src 'self' 'unsafe-inline' https://appleid.cdn-apple.com; \
                style-src 'self' 'unsafe-inline'; \
                img-src 'self' data: https:; \
                font-src 'self'; \
                connect-src 'self' https://appleid.apple.com; \
                frame-ancestors 'none'; \
                form-action 'self'; \
                base-uri 'self'
                """
            )
        }

        // Strict Transport Security (HTTPS only)
        if request.application.environment == .production {
            response.headers.add(
                name: "Strict-Transport-Security",
                value: "max-age=31536000; includeSubDomains; preload"
            )
        }

        // Cache control for API responses
        if request.url.path.hasPrefix("/api/") {
            response.headers.add(name: "Cache-Control", value: "no-store, no-cache, must-revalidate")
            response.headers.add(name: "Pragma", value: "no-cache")
        }

        return response
    }
}

// MARK: - Input Validation Helpers

extension Request {
    /// Validate and sanitize string input
    func sanitizedString(_ value: String, maxLength: Int = 10000) throws -> String {
        guard value.count <= maxLength else {
            throw Abort(.badRequest, reason: "Input exceeds maximum length of \(maxLength)")
        }

        // Remove null bytes and control characters (except newlines)
        let sanitized = value.filter { char in
            !char.isASCII || char == "\n" || char == "\r" || char == "\t" ||
            (char.asciiValue ?? 0 >= 32 && char.asciiValue ?? 0 < 127) ||
            char.asciiValue ?? 0 > 127
        }

        return sanitized
    }

    /// Validate email format
    func validateEmail(_ email: String) throws -> String {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard email.range(of: emailRegex, options: .regularExpression) != nil else {
            throw Abort(.badRequest, reason: "Invalid email format")
        }
        guard email.count <= 254 else {
            throw Abort(.badRequest, reason: "Email too long")
        }
        return email.lowercased()
    }

    /// Validate UUID string
    func validateUUID(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw Abort(.badRequest, reason: "Invalid UUID format")
        }
        return uuid
    }
}
