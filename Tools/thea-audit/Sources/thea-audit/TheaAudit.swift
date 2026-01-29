// TheaAudit.swift
// thea-audit - Security scanner for Thea application
// Part of AgentSec Strict Mode implementation

import ArgumentParser

@main
struct TheaAudit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "thea-audit",
        abstract: "Security scanner for Thea application",
        discussion: """
        thea-audit scans Swift code, GitHub workflows, shell scripts, and MCP servers
        for security vulnerabilities and policy violations.

        Part of the AgentSec Strict Mode implementation.
        """,
        version: "1.0.0",
        subcommands: [AuditCommand.self, PolicyCommand.self],
        defaultSubcommand: AuditCommand.self
    )
}
