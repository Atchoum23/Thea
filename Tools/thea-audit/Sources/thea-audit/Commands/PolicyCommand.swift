// PolicyCommand.swift
// Command to generate or validate AgentSec policy files

import ArgumentParser
import Foundation

struct PolicyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "policy",
        abstract: "Generate or validate AgentSec policy files",
        subcommands: [GeneratePolicy.self, ValidatePolicy.self]
    )
}

// MARK: - Generate Policy Subcommand

struct GeneratePolicy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a new AgentSec policy file"
    )

    @Option(name: .shortAndLong, help: "Output path for policy file")
    var output: String = "thea-policy.json"

    @Option(name: .long, help: "Policy template (strict, standard, permissive)")
    var template: PolicyTemplate = .strict

    @Flag(name: .shortAndLong, help: "Overwrite existing file")
    var force: Bool = false

    func run() throws {
        let fileManager = FileManager.default

        // Check if file exists
        if fileManager.fileExists(atPath: output), !force {
            throw PolicyError.fileExists(output)
        }

        // Generate policy based on template
        let policy = AgentSecPolicy.template(template)

        // Write to file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(policy)

        try data.write(to: URL(fileURLWithPath: output))

        print("Generated \(template.rawValue) policy: \(output)")
    }
}

// MARK: - Validate Policy Subcommand

struct ValidatePolicy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate an AgentSec policy file"
    )

    @Argument(help: "Path to policy file")
    var path: String

    func run() throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        let policy = try decoder.decode(AgentSecPolicy.self, from: data)

        // Validate policy
        let issues = policy.validate()

        if issues.isEmpty {
            print("Policy is valid: \(path)")
            print("")
            print("Summary:")
            print("  Blocked hosts: \(policy.network.blockedHosts.count)")
            print("  Blocked paths: \(policy.filesystem.blockedPaths.count)")
            print("  Blocked patterns: \(policy.terminal.blockedPatterns.count)")
            print("  Required approvals: \(policy.approval.requiredForTypes.count)")
            print("  Kill switch: \(policy.killSwitch.enabled ? "enabled" : "disabled")")
        } else {
            print("Policy validation failed: \(path)")
            print("")
            for issue in issues {
                print("  - \(issue)")
            }
            throw PolicyError.validationFailed(issues)
        }
    }
}

// MARK: - Policy Errors

enum PolicyError: Error, CustomStringConvertible {
    case fileExists(String)
    case validationFailed([String])

    var description: String {
        switch self {
        case let .fileExists(path):
            "File already exists: \(path). Use --force to overwrite."
        case let .validationFailed(issues):
            "Policy validation failed: \(issues.joined(separator: ", "))"
        }
    }
}
