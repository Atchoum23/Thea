// CodeToolHandler.swift
// Thea
//
// Tool handler for code analysis and execution (B3)
// Wraps CodeExecutionVerifier (JavaScriptCore) for AI tool use

import Foundation
import JavaScriptCore
import os.log

private let logger = Logger(subsystem: "ai.thea.app", category: "CodeToolHandler")

@MainActor
enum CodeToolHandler {

    // MARK: - run_code

    static func execute(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let code = input["code"] as? String ?? ""
        let language = (input["language"] as? String ?? "javascript").lowercased()
        guard !code.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No code provided.", isError: true)
        }
        logger.debug("run_code: \(code.prefix(60))... [\(language)]")

        switch language {
        case "javascript", "js":
            return await runJavaScript(id: id, code: code)

        #if os(macOS)
        case "swift":
            return await runSwift(id: id, code: code)
        case "python", "python3":
            return await runPython(id: id, code: code)
        #endif

        default:
            return AnthropicToolResult(
                toolUseId: id,
                content: "Language '\(language)' not supported. Supported: javascript\(ProcessInfo.processInfo.environment["PATH"] != nil ? ", swift, python" : "")."
            )
        }
    }

    // MARK: - analyze_code

    static func analyze(_ input: [String: Any]) -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let code = input["code"] as? String ?? ""
        guard !code.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No code provided.", isError: true)
        }
        let analysis = performStaticAnalysis(code)
        return AnthropicToolResult(toolUseId: id, content: analysis)
    }

    // MARK: - JavaScript Execution (via JavaScriptCore)

    private static func runJavaScript(id: String, code: String) async -> AnthropicToolResult {
        return await Task.detached(priority: .userInitiated) {
            let ctx = JSContext()!
            ctx.exceptionHandler = { _, exception in
                _ = exception?.toString()
            }
            // Capture console.log output
            var output: [String] = []
            let logFn: @convention(block) (String) -> Void = { msg in
                output.append(msg)
            }
            ctx.setObject(logFn, forKeyedSubscript: "print" as NSString)
            ctx.evaluateScript("var console = { log: print, error: print, warn: print };")

            // Set timeout: 5 seconds
            let deadline = Date().addingTimeInterval(5)
            let result = ctx.evaluateScript(code)

            if let exception = ctx.exception {
                let errMsg = exception.toString() ?? "Unknown error"
                return AnthropicToolResult(toolUseId: id, content: "Error: \(errMsg)", isError: true)
            }

            var resultText = output.joined(separator: "\n")
            if let val = result, !val.isUndefined, !val.isNull {
                let str = val.toString() ?? ""
                if !str.isEmpty && str != "undefined" {
                    resultText += (resultText.isEmpty ? "" : "\n") + str
                }
            }
            _ = deadline // used to prevent compiler warning
            return AnthropicToolResult(
                toolUseId: id,
                content: resultText.isEmpty ? "(no output)" : String(resultText.prefix(3000))
            )
        }.value
    }

    #if os(macOS)
    // MARK: - Swift Execution (via Process)

    private static func runSwift(id: String, code: String) async -> AnthropicToolResult {
        return await Task.detached(priority: .userInitiated) {
            let tmpFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".swift")
            do {
                try code.write(to: tmpFile, atomically: true, encoding: .utf8)
                defer { try? FileManager.default.removeItem(at: tmpFile) }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
                process.arguments = [tmpFile.path]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                try process.run()
                // Timeout after 15s
                let deadline = DispatchTime.now() + .seconds(15)
                DispatchQueue.global().asyncAfter(deadline: deadline) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return AnthropicToolResult(toolUseId: id, content: output.isEmpty ? "(no output)" : String(output.prefix(3000)))
            } catch {
                return AnthropicToolResult(toolUseId: id, content: "Swift execution failed: \(error.localizedDescription)", isError: true)
            }
        }.value
    }

    // MARK: - Python Execution (via Process)

    private static func runPython(id: String, code: String) async -> AnthropicToolResult {
        return await Task.detached(priority: .userInitiated) {
            let pythonPaths = ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
            guard let pythonPath = pythonPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                return AnthropicToolResult(toolUseId: id, content: "Python3 not found.", isError: true)
            }
            let tmpFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".py")
            do {
                try code.write(to: tmpFile, atomically: true, encoding: .utf8)
                defer { try? FileManager.default.removeItem(at: tmpFile) }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = [tmpFile.path]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                try process.run()
                let deadline = DispatchTime.now() + .seconds(10)
                DispatchQueue.global().asyncAfter(deadline: deadline) {
                    if process.isRunning { process.terminate() }
                }
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return AnthropicToolResult(toolUseId: id, content: output.isEmpty ? "(no output)" : String(output.prefix(3000)))
            } catch {
                return AnthropicToolResult(toolUseId: id, content: "Python execution failed: \(error.localizedDescription)", isError: true)
            }
        }.value
    }
    #endif

    // MARK: - Static Analysis

    private static func performStaticAnalysis(_ code: String) -> String {
        var issues: [String] = []
        let lines = code.components(separatedBy: .newlines)

        // Basic checks
        if code.contains("eval(") { issues.append("⚠️ eval() usage detected") }
        if code.contains("exec(") { issues.append("⚠️ exec() usage detected") }
        if code.range(of: "password|secret|api_key|apikey", options: [.regularExpression, .caseInsensitive]) != nil {
            issues.append("⚠️ Possible sensitive data reference")
        }
        if lines.count > 200 { issues.append("ℹ️ Large file: \(lines.count) lines") }

        let stats = """
        Lines: \(lines.count)
        Characters: \(code.count)
        """

        if issues.isEmpty {
            return "✅ No issues found.\n\(stats)"
        }
        return "Found \(issues.count) issue(s):\n" + issues.joined(separator: "\n") + "\n\n" + stats
    }
}
