#if os(macOS)
import SwiftUI

// MARK: - QA Settings View

struct QASettingsView: View {
    @State private var config = AppConfiguration.shared.qaToolsConfig
    @State private var qaManager = QAToolsManager.shared
    @State private var selectedTab = 0
    @State private var showingRunConfirmation = false
    @State private var toolToRun: QATool?
    @State private var runAllInProgress = false

    var body: some View {
        Form {
            Section("QA Tools") {
                Text("Configure and run third-party quality assurance tools")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Quick Actions Section
            Section("Quick Actions") {
                HStack {
                    Button {
                        Task {
                            runAllInProgress = true
                            _ = await qaManager.runAllTools()
                            runAllInProgress = false
                        }
                    } label: {
                        Label("Run All Enabled", systemImage: "play.circle.fill")
                    }
                    .disabled(qaManager.isRunning || runAllInProgress)

                    if qaManager.isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.leading, 8)
                        if let tool = qaManager.currentTool {
                            Text("Running \(tool.displayName)...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !qaManager.lastResults.isEmpty {
                    Divider()
                    lastResultsSummary
                }
            }

            // SwiftLint Section
            swiftLintSection

            // CodeCov Section
            codeCovSection

            // SonarCloud Section
            sonarCloudSection

            // DeepSource Section
            deepSourceSection

            // Project Configuration Section
            projectConfigSection

            // Automation Section
            automationSection

            // History Section
            if !qaManager.history.isEmpty {
                historySection
            }

            // Reset Section
            Section {
                Button("Reset to Defaults") {
                    config = QAToolsConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.qaToolsConfig = newValue
        }
    }

    // MARK: - Last Results Summary

    private var lastResultsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Run Results")
                .font(.headline)

            ForEach(Array(qaManager.lastResults.values), id: \.id) { result in
                HStack {
                    Image(systemName: result.tool.icon)
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.tool.displayName)
                    Spacer()
                    if result.success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        HStack(spacing: 4) {
                            if result.errorsFound > 0 {
                                Label("\(result.errorsFound)", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            if result.warningsFound > 0 {
                                Label("\(result.warningsFound)", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - SwiftLint Section

    private var swiftLintSection: some View {
        Section {
            Toggle("Enable SwiftLint", isOn: $config.swiftLintEnabled)

            if config.swiftLintEnabled {
                TextField("Executable Path", text: $config.swiftLintExecutablePath)
                    .help("Path to swiftlint binary (e.g., /opt/homebrew/bin/swiftlint)")

                TextField("Config File", text: $config.swiftLintConfigPath)
                    .help("Path to .swiftlint.yml relative to project root")

                Toggle("Auto-fix Issues", isOn: $config.swiftLintAutoFix)
                    .help("Automatically fix correctable issues when running")

                Toggle("Run on Build", isOn: $config.swiftLintRunOnBuild)
                    .help("Run SwiftLint automatically during Xcode builds")

                HStack {
                    Button {
                        Task {
                            _ = await qaManager.runSwiftLint()
                        }
                    } label: {
                        Label("Run SwiftLint", systemImage: "play.fill")
                    }
                    .disabled(qaManager.isRunning)

                    Button {
                        Task {
                            _ = await qaManager.runSwiftLint(autoFix: true)
                        }
                    } label: {
                        Label("Run with Auto-fix", systemImage: "wand.and.stars")
                    }
                    .disabled(qaManager.isRunning)
                }

                if let result = qaManager.lastResults[.swiftLint] {
                    lastResultView(for: result)
                }
            }
        } header: {
            Label("SwiftLint", systemImage: "swift")
        } footer: {
            Text("Static code analysis for Swift style and conventions")
        }
    }

    // MARK: - CodeCov Section

    private var codeCovSection: some View {
        Section {
            Toggle("Enable CodeCov", isOn: $config.codeCovEnabled)

            if config.codeCovEnabled {
                SecureField("Upload Token", text: $config.codeCovToken)
                    .help("Get this from codecov.io → Settings → Upload Token")

                TextField("Config File", text: $config.codeCovConfigPath)
                    .help("Path to codecov.yml relative to project root")

                Toggle("Upload on CI Only", isOn: $config.codeCovUploadOnCI)
                    .help("Only upload coverage when running in CI environment")

                Button {
                    Task {
                        _ = await qaManager.uploadCoverage()
                    }
                } label: {
                    Label("Upload Coverage", systemImage: "arrow.up.circle.fill")
                }
                .disabled(qaManager.isRunning || config.codeCovToken.isEmpty)

                if let result = qaManager.lastResults[.codeCov] {
                    lastResultView(for: result)
                }
            }
        } header: {
            Label("CodeCov", systemImage: "chart.pie")
        } footer: {
            Text("Code coverage reporting and tracking")
        }
    }

    // MARK: - SonarCloud Section

    private var sonarCloudSection: some View {
        Section {
            Toggle("Enable SonarCloud", isOn: $config.sonarCloudEnabled)

            if config.sonarCloudEnabled {
                SecureField("Token", text: $config.sonarCloudToken)
                    .help("Get this from sonarcloud.io → My Account → Security → Generate Token")

                TextField("Organization", text: $config.sonarCloudOrganization)
                    .help("Your SonarCloud organization key")

                TextField("Project Key", text: $config.sonarCloudProjectKey)
                    .help("Unique identifier for your project on SonarCloud")

                TextField("Config File", text: $config.sonarCloudConfigPath)
                    .help("Path to sonar-project.properties relative to project root")

                TextField("Base URL", text: $config.sonarCloudBaseURL)
                    .help("SonarCloud API base URL")

                Button {
                    Task {
                        _ = await qaManager.runSonarAnalysis()
                    }
                } label: {
                    Label("Run Analysis", systemImage: "magnifyingglass")
                }
                .disabled(
                    qaManager.isRunning ||
                    config.sonarCloudToken.isEmpty ||
                    config.sonarCloudOrganization.isEmpty
                )

                if let result = qaManager.lastResults[.sonarCloud] {
                    lastResultView(for: result)
                }
            }
        } header: {
            Label("SonarCloud", systemImage: "cloud")
        } footer: {
            Text("Continuous code quality and security analysis. Requires sonar-scanner CLI.")
        }
    }

    // MARK: - DeepSource Section

    private var deepSourceSection: some View {
        Section {
            Toggle("Enable DeepSource", isOn: $config.deepSourceEnabled)

            if config.deepSourceEnabled {
                SecureField("DSN", text: $config.deepSourceDSN)
                    .help("Get this from deepsource.io → Project Settings → DSN")

                TextField("Config File", text: $config.deepSourceConfigPath)
                    .help("Path to .deepsource.toml relative to project root")

                Button {
                    Task {
                        _ = await qaManager.runDeepSourceAnalysis()
                    }
                } label: {
                    Label("Run Analysis", systemImage: "magnifyingglass.circle")
                }
                .disabled(qaManager.isRunning || config.deepSourceDSN.isEmpty)

                if let result = qaManager.lastResults[.deepSource] {
                    lastResultView(for: result)
                }
            }
        } header: {
            Label("DeepSource", systemImage: "magnifyingglass.circle")
        } footer: {
            Text("Automated code review and issue detection. Requires DeepSource CLI.")
        }
    }

    // MARK: - Project Configuration Section

    private var projectConfigSection: some View {
        Section("Project Configuration") {
            TextField("Project Root Path", text: $config.projectRootPath)
                .help("Leave empty to use default Thea development path")

            TextField("Xcode Scheme", text: $config.xcodeScheme)
                .help("The Xcode scheme to use for building and testing")

            TextField("Xcode Destination", text: $config.xcodeDestination)
                .help("Build destination (e.g., platform=macOS)")

            Toggle("Enable Code Coverage", isOn: $config.enableCodeCoverage)

            TextField("Coverage Output Path", text: $config.coverageOutputPath)
                .help("Directory for coverage reports")

            TextField("Test Result Bundle Path", text: $config.testResultBundlePath)
                .help("Path for xcodebuild test results")
        }
    }

    // MARK: - Automation Section

    private var automationSection: some View {
        Section("Automation") {
            Toggle("Run QA on Build", isOn: $config.runQAOnBuild)
                .help("Automatically run enabled QA tools during builds")

            Toggle("Run QA on Commit", isOn: $config.runQAOnCommit)
                .help("Automatically run enabled QA tools before commits")

            Toggle("Fail Build on QA Errors", isOn: $config.failBuildOnQAErrors)
                .help("Prevent build completion if QA tools find errors")

            Toggle("Show QA Notifications", isOn: $config.showQANotifications)
                .help("Display system notifications for QA results")

            Stepper("Keep History: \(config.keepHistoryDays) days", value: $config.keepHistoryDays, in: 7...365, step: 7)

            Stepper("Max History Entries: \(config.maxHistoryEntries)", value: $config.maxHistoryEntries, in: 10...1_000, step: 10)
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        Section {
            ForEach(qaManager.history.suffix(10).reversed()) { result in
                HStack {
                    Image(systemName: result.tool.icon)
                        .foregroundStyle(result.success ? .green : .red)
                    VStack(alignment: .leading) {
                        Text(result.tool.displayName)
                            .font(.headline)
                        Text(result.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if result.success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        VStack(alignment: .trailing) {
                            if result.errorsFound > 0 {
                                Text("\(result.errorsFound) errors")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            if result.warningsFound > 0 {
                                Text("\(result.warningsFound) warnings")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            Button("Clear History") {
                qaManager.clearHistory()
            }
            .foregroundStyle(.red)
        } header: {
            Label("Recent History", systemImage: "clock")
        }
    }

    // MARK: - Helper Views

    private func lastResultView(for result: QAToolResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            HStack {
                Text("Last Run:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.timestamp, style: .relative)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1fs", result.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if result.success {
                    Label("Passed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    if result.errorsFound > 0 {
                        Label("\(result.errorsFound) errors", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    if result.warningsFound > 0 {
                        Label("\(result.warningsFound) warnings", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }

            if !result.details.isEmpty {
                NavigationLink {
                    QAIssuesDetailView(result: result)
                } label: {
                    Text("View \(result.details.count) issues")
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - QA Issues Detail View

struct QAIssuesDetailView: View {
    let result: QAToolResult

    var body: some View {
        List {
            ForEach(result.details) { issue in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: issue.severity.icon)
                            .foregroundStyle(severityColor(issue.severity))
                        Text(issue.message)
                            .font(.body)
                    }

                    if let file = issue.file {
                        HStack {
                            Text(file)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let line = issue.line {
                                Text("Line \(line)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let rule = issue.rule {
                                Text("[\(rule)]")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("\(result.tool.displayName) Issues")
    }

    private func severityColor(_ severity: QAIssueSeverity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .hint: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    QASettingsView()
}

#endif
