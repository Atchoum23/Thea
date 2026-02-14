// BuildVerificationAgent.swift
// Thea V2
//
// Verifies builds and runs tests with error parsing.
// Extracted from BlueprintExecutor.swift for file length compliance.

import Foundation

// MARK: - Build Verification Agent

/// Verifies builds and runs tests with error parsing
@MainActor
final class BuildVerificationAgent {
    func verifyBuild(scheme: String, configuration: String = "Debug") async -> BlueprintBuildResult {
        #if os(macOS)
        let command = "xcodebuild -scheme \(scheme) -configuration \(configuration) build 2>&1"

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let errors = parseBuildErrors(output)

            return BlueprintBuildResult(
                success: errors.isEmpty && output.contains("BUILD SUCCEEDED"),
                errors: errors,
                warnings: parseBuildWarnings(output),
                output: output
            )
        } catch {
            return BlueprintBuildResult(
                success: false,
                errors: [BlueprintBuildError(message: error.localizedDescription, file: nil, line: nil)],
                warnings: [],
                output: ""
            )
        }
        #else
        return BlueprintBuildResult(
            success: false,
            errors: [BlueprintBuildError(message: "Build verification not available on this platform", file: nil, line: nil)],
            warnings: [],
            output: ""
        )
        #endif
    }

    func runTests(target: String? = nil) async -> BlueprintTestResult {
        #if os(macOS)
        let command = target != nil
            ? "swift test --filter \(target!)"
            : "swift test"

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let passed = output.contains("Test Suite") && output.contains("passed")
            let failures = parseTestFailures(output)

            return BlueprintTestResult(
                success: passed && failures.isEmpty,
                failures: failures,
                output: output
            )
        } catch {
            return BlueprintTestResult(
                success: false,
                failures: [BlueprintTestFailure(test: "Unknown", message: error.localizedDescription)],
                output: ""
            )
        }
        #else
        return BlueprintTestResult(
            success: false,
            failures: [BlueprintTestFailure(test: "Unknown", message: "Test execution not available on this platform")],
            output: ""
        )
        #endif
    }

    private func parseBuildErrors(_ output: String) -> [BlueprintBuildError] {
        var errors: [BlueprintBuildError] = []
        let pattern = #"(.+?):(\d+):(\d+): error: (.+)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(output.startIndex..., in: output)
            let matches = regex.matches(in: output, range: range)

            for match in matches {
                if let fileRange = Range(match.range(at: 1), in: output),
                   let lineRange = Range(match.range(at: 2), in: output),
                   let messageRange = Range(match.range(at: 4), in: output) {
                    errors.append(BlueprintBuildError(
                        message: String(output[messageRange]),
                        file: String(output[fileRange]),
                        line: Int(output[lineRange])
                    ))
                }
            }
        }

        return errors
    }

    private func parseBuildWarnings(_ output: String) -> [BlueprintBuildWarning] {
        var warnings: [BlueprintBuildWarning] = []
        let pattern = #"(.+?):(\d+):(\d+): warning: (.+)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(output.startIndex..., in: output)
            let matches = regex.matches(in: output, range: range)

            for match in matches {
                if let fileRange = Range(match.range(at: 1), in: output),
                   let messageRange = Range(match.range(at: 4), in: output) {
                    warnings.append(BlueprintBuildWarning(
                        message: String(output[messageRange]),
                        file: String(output[fileRange])
                    ))
                }
            }
        }

        return warnings
    }

    private func parseTestFailures(_ output: String) -> [BlueprintTestFailure] {
        var failures: [BlueprintTestFailure] = []
        let pattern = #"Test Case .+ '(.+)' failed"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(output.startIndex..., in: output)
            let matches = regex.matches(in: output, range: range)

            for match in matches {
                if let testRange = Range(match.range(at: 1), in: output) {
                    failures.append(BlueprintTestFailure(
                        test: String(output[testRange]),
                        message: "Test failed"
                    ))
                }
            }
        }

        return failures
    }
}
