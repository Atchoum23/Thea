#if os(macOS)
    import Foundation
    import OSLog

    // MARK: - AutonomousBuildLoop

    // Autonomous build-fix-retry loop for self-healing code

    public actor AutonomousBuildLoop {
        public static let shared = AutonomousBuildLoop()

        private let logger = Logger(subsystem: "com.thea.metaai", category: "AutonomousBuildLoop")

        private init() {}

        // MARK: - Public Types

        public struct LoopResult: Sendable {
            public let success: Bool
            public let iterations: Int
            public let errorsFixed: Int
            public let errorsFailed: Int
            public let duration: TimeInterval
            public let finalBuildResult: XcodeBuildRunner.BuildResult

            public init(
                success: Bool,
                iterations: Int,
                errorsFixed: Int,
                errorsFailed: Int,
                duration: TimeInterval,
                finalBuildResult: XcodeBuildRunner.BuildResult
            ) {
                self.success = success
                self.iterations = iterations
                self.errorsFixed = errorsFixed
                self.errorsFailed = errorsFailed
                self.duration = duration
                self.finalBuildResult = finalBuildResult
            }
        }

        public enum LoopError: LocalizedError, Sendable {
            case maxIterationsReached
            case savepointFailed
            case noFixableErrors

            public var errorDescription: String? {
                switch self {
                case .maxIterationsReached:
                    "Maximum iterations reached without successful build"
                case .savepointFailed:
                    "Failed to create git savepoint"
                case .noFixableErrors:
                    "No fixable errors found"
                }
            }
        }

        // MARK: - Run Loop

        public func run(
            maxIterations: Int = 10,
            scheme: String = "Thea-macOS",
            configuration: String = "Debug"
        ) async throws -> LoopResult {
            logger.info("🚀 Starting autonomous build loop (max \(maxIterations) iterations)")

            var iteration = 0
            var errorsFixed = 0
            var errorsFailed = 0
            let startTime = Date()

            // Create savepoint before starting
            let savepoint = try await GitSavepoint.shared.createSavepoint(
                message: "Pre-autonomous-fix savepoint"
            )
            logger.info("Created savepoint: \(savepoint)")

            while iteration < maxIterations {
                iteration += 1
                logger.info("📍 Build iteration \(iteration)/\(maxIterations)")

                // STEP 1: Build
                let buildResult = try await XcodeBuildRunner.shared.build(
                    scheme: scheme,
                    configuration: configuration
                )

                // Check if build succeeded
                if buildResult.success {
                    logger.info("✅ Build succeeded after \(iteration) iterations")
                    logger.info("📊 Fixed: \(errorsFixed), Failed: \(errorsFailed)")

                    return LoopResult(
                        success: true,
                        iterations: iteration,
                        errorsFixed: errorsFixed,
                        errorsFailed: errorsFailed,
                        duration: Date().timeIntervalSince(startTime),
                        finalBuildResult: buildResult
                    )
                }

                // STEP 2: Parse errors
                logger.info("❌ Build failed with \(buildResult.errors.count) errors")

                // Get top issues for logging
                let topIssues = buildResult.errors
                    .deduplicated()
                    .sortedByLocation()
                    .filter(\.isError)
                    .prefix(5)

                if !topIssues.isEmpty {
                    let previewList = topIssues.map { "   • \($0.compactDisplayString)" }.joined(separator: "\n")
                    logger.info("Top issues:\n\(previewList)")
                }

                // Debug severity summary for observability
                let errorCount = buildResult.errors.count { $0.errorType == .error }
                let warningCount = buildResult.errors.count { $0.errorType == .warning }
                let noteCount = buildResult.errors.count { $0.errorType == .note }
                logger.debug("Severity summary — errors: \(errorCount), warnings: \(warningCount), notes: \(noteCount)")

                let parsedErrors = await ErrorParser.shared.parse(buildResult.errors)

                guard !parsedErrors.isEmpty else {
                    logger.error("Build failed but no parseable errors found")
                    throw LoopError.noFixableErrors
                }

                // Log error statistics
                let stats = await ErrorParser.shared.analyzeErrors(parsedErrors)
                logger.info("Error categories: \(stats.categoryCounts)")
                logger.info("Fix coverage: \(String(format: "%.1f%%", stats.fixCoverage * 100))")

                // STEP 3: Fix first error
                let firstError = parsedErrors[0]
                logger.info("🔧 Attempting to fix: \(firstError.file):\(firstError.line) - \(firstError.message)")
                logger.info("   Category: \(firstError.category.rawValue)")

                // Try to find a known fix
                if let knownFix = await ErrorKnowledgeBase.shared.findFix(for: firstError) {
                    logger.info("   Found fix strategy: \(knownFix.fixStrategy.rawValue) (confidence: \(String(format: "%.2f", knownFix.confidence)))")

                    // Apply the fix
                    do {
                        let fixResult = try await CodeFixer.shared.applyFix(knownFix, to: firstError)

                        if fixResult.applied {
                            errorsFixed += 1
                            logger.info("   ✅ Fix applied: \(fixResult.changeDescription)")
                            await ErrorKnowledgeBase.shared.recordResult(fix: knownFix, success: true)
                        } else {
                            errorsFailed += 1
                            logger.warning("   ⚠️  Fix not applied: \(fixResult.changeDescription)")
                            await ErrorKnowledgeBase.shared.recordResult(fix: knownFix, success: false)

                            // If we can't fix this error, try the next iteration
                            // The build might reveal different errors
                        }
                    } catch {
                        errorsFailed += 1
                        logger.error("   ❌ Fix failed: \(error.localizedDescription)")
                        await ErrorKnowledgeBase.shared.recordResult(fix: knownFix, success: false)
                    }
                } else {
                    errorsFailed += 1
                    logger.warning("   ⚠️  No known fix for this error category")

                    // Could invoke AI here for unknown errors
                    logger.info("   Suggested: \(firstError.suggestedFix ?? "none")")
                }

                // Safety check: if we've failed too many times without progress, stop
                if errorsFailed > errorsFixed, errorsFailed > 5 {
                    logger.warning("Too many failed fixes (\(errorsFailed)), stopping")
                    break
                }
            }

            // Failed after max iterations
            logger.error("❌ Build loop failed after \(iteration) iterations")
            let finalBuild = try await XcodeBuildRunner.shared.build(scheme: scheme, configuration: configuration)

            return LoopResult(
                success: false,
                iterations: iteration,
                errorsFixed: errorsFixed,
                errorsFailed: errorsFailed,
                duration: Date().timeIntervalSince(startTime),
                finalBuildResult: finalBuild
            )
        }

        // MARK: - Run with Rollback on Failure

        public func runWithRollback(
            maxIterations: Int = 10,
            scheme: String = "Thea-macOS",
            configuration: String = "Debug"
        ) async throws -> LoopResult {
            // Create savepoint
            let savepoint = try await GitSavepoint.shared.createSavepoint(
                message: "Pre-autonomous-fix savepoint (with rollback)"
            )

            do {
                let result = try await run(maxIterations: maxIterations, scheme: scheme, configuration: configuration)

                if !result.success {
                    // Build failed, rollback
                    logger.warning("Build failed, rolling back to savepoint")
                    try await GitSavepoint.shared.rollback(to: savepoint)
                }

                return result
            } catch {
                // Error occurred, rollback
                logger.error("Error during build loop, rolling back to savepoint: \(error.localizedDescription)")
                try await GitSavepoint.shared.rollback(to: savepoint)
                throw error
            }
        }

        // MARK: - Dry Run (No File Modifications)

        public func dryRun(
            maxIterations _: Int = 10,
            scheme: String = "Thea-macOS"
        ) async throws -> [String] {
            logger.info("🔍 Running dry run analysis")

            var suggestedFixes: [String] = []

            // Build once to get errors
            let buildResult = try await XcodeBuildRunner.shared.build(scheme: scheme)

            if buildResult.success {
                return ["Build already successful - no fixes needed"]
            }

            // Parse and analyze errors
            let parsedErrors = await ErrorParser.shared.parse(buildResult.errors)
            let stats = await ErrorParser.shared.analyzeErrors(parsedErrors)

            suggestedFixes.append("Found \(parsedErrors.count) errors in \(stats.categoryCounts.count) categories")
            suggestedFixes.append("Fix coverage: \(String(format: "%.1f%%", stats.fixCoverage * 100))")
            suggestedFixes.append("")

            // Analyze each error
            for (index, error) in parsedErrors.prefix(10).enumerated() {
                suggestedFixes.append("\(index + 1). \(error.file):\(error.line)")
                suggestedFixes.append("   Category: \(error.category.rawValue)")
                suggestedFixes.append("   Message: \(error.message)")

                if let knownFix = await ErrorKnowledgeBase.shared.findFix(for: error) {
                    suggestedFixes.append("   Fix: \(knownFix.fixStrategy.rawValue) (confidence: \(String(format: "%.2f", knownFix.confidence)))")
                    suggestedFixes.append("   Description: \(knownFix.fixDescription)")
                } else {
                    suggestedFixes.append("   Fix: None found")
                    if let suggestion = error.suggestedFix {
                        suggestedFixes.append("   Suggestion: \(suggestion)")
                    }
                }
                suggestedFixes.append("")
            }

            if parsedErrors.count > 10 {
                suggestedFixes.append("... and \(parsedErrors.count - 10) more errors")
            }

            return suggestedFixes
        }

        // MARK: - Statistics

        public func getKnowledgeBaseStatistics() async -> KnowledgeBaseStatistics {
            await ErrorKnowledgeBase.shared.getStatistics()
        }
    }

#endif
