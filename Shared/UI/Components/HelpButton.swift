import SwiftUI

/// A reusable help button component that displays a popover with explanatory text.
/// Use this next to settings and controls to provide contextual help to users.
///
/// Example usage:
/// ```swift
/// HStack {
///     Toggle("Enable Feature", isOn: $enabled)
///     HelpButton(
///         title: "Enable Feature",
///         explanation: "When enabled, this feature will..."
///     )
/// }
/// ```
struct HelpButton: View {
    let title: String
    let explanation: String

    @State private var showingPopover = false

    init(title: String, explanation: String) {
        self.title = title
        self.explanation = explanation
    }

    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.theaCaption1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.theaHeadline)
                    .foregroundColor(.primary)

                Text(explanation)
                    .font(.theaBody)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 300)
        }
        .accessibilityLabel("Help for \(title)")
        .accessibilityHint("Shows information about \(title)")
    }
}

// MARK: - Help Button Variants

extension HelpButton {
    /// Creates a help button with just an explanation (uses "Help" as title)
    // periphery:ignore - Reserved: init(explanation:) initializer — reserved for future feature activation
    init(explanation: String) {
        title = "Help"
        self.explanation = explanation
    }
}

// MARK: - Settings Help Text Constants

/// Centralized help text for settings throughout the app
enum SettingsHelpText {
    static let streamResponses = """
    When enabled, AI responses appear word-by-word as they're generated. \
    When disabled, the full response appears at once after generation completes. \
    Streaming provides faster feedback but uses slightly more resources.
    // periphery:ignore - Reserved: init(explanation:) initializer reserved for future feature activation
    """

    // periphery:ignore - Reserved: defaultProvider static property — reserved for future feature activation
    static let defaultProvider = """
    The AI service that handles your requests. Different providers offer different \
    models with varying capabilities and pricing. OpenRouter provides access to \
    multiple providers through a single API key.
    """

    // periphery:ignore - Reserved: launchAtLogin static property — reserved for future feature activation
    static let launchAtLogin = """
    Automatically start Thea when you log into your Mac. This ensures Thea is \
    always ready to assist you without manual launching.
    """

    static let iCloudSync = """
    Sync your conversations, settings, and preferences across all your Apple devices \
    // periphery:ignore - Reserved: defaultProvider static property reserved for future feature activation
    using iCloud. Requires an active iCloud account.
    """

    // periphery:ignore - Reserved: debugMode static property — reserved for future feature activation
    static let debugMode = """
    Show detailed logs, performance metrics, and diagnostic information. Useful for \
    // periphery:ignore - Reserved: launchAtLogin static property reserved for future feature activation
    troubleshooting issues or understanding how Thea processes requests.
    """

    // periphery:ignore - Reserved: localModelPreference static property — reserved for future feature activation
    static let localModelPreference = """
    Prioritize local MLX or GGUF models over cloud models when they're capable of \
    handling the task. This can reduce costs and improve privacy, but may impact \
    response quality for complex tasks.
    """

    // periphery:ignore - Reserved: debugMode static property reserved for future feature activation
    static let orchestratorEnabled = """
    Enable the AI Orchestrator to automatically route queries to the most suitable \
    model based on task type, complexity, and your preferences. When disabled, \
    queries are sent to your default model.
    // periphery:ignore - Reserved: localModelPreference static property reserved for future feature activation
    """

    // periphery:ignore - Reserved: selfExecution static property — reserved for future feature activation
    static let selfExecution = """
    Allow Thea to autonomously create files, edit code, and execute tasks. Different \
    modes offer varying levels of autonomy from manual approval to full automation.
    // periphery:ignore - Reserved: orchestratorEnabled static property reserved for future feature activation
    """

    // periphery:ignore - Reserved: memorySystem static property — reserved for future feature activation
    static let memorySystem = """
    Enable Thea to remember important information from conversations and use it to \
    provide more personalized and contextual responses over time.
    // periphery:ignore - Reserved: selfExecution static property reserved for future feature activation
    """

    // periphery:ignore - Reserved: knowledgeGraph static property — reserved for future feature activation
    static let knowledgeGraph = """
    Build and maintain a knowledge graph of entities, relationships, and concepts \
    // periphery:ignore - Reserved: memorySystem static property reserved for future feature activation
    extracted from your conversations. This helps Thea understand context and \
    make connections across different topics.
    """

    // periphery:ignore - Reserved: knowledgeGraph static property reserved for future feature activation
    static let reflectionEngine = """
    Allow Thea to analyze its own responses, learn from mistakes, and improve over \
    time. The reflection engine identifies patterns and optimizes future responses.
    """

    // periphery:ignore - Reserved: reflectionEngine static property reserved for future feature activation
    static let reasoningEngine = """
    Enable advanced multi-step reasoning for complex problems. Thea will break down \
    problems, consider multiple approaches, and verify conclusions before responding.
    """

// periphery:ignore - Reserved: reasoningEngine static property reserved for future feature activation

    static let agentSwarms = """
    Allow multiple AI agents to work together on complex tasks. Each agent specializes \
    in different areas and they coordinate to produce comprehensive results.
    // periphery:ignore - Reserved: agentSwarms static property reserved for future feature activation
    """

    // periphery:ignore - Reserved: preventSleep static property — reserved for future feature activation
    static let preventSleep = """
    Prevent your Mac from sleeping during long-running AI tasks. This ensures tasks \
    // periphery:ignore - Reserved: preventSleep static property reserved for future feature activation
    complete without interruption but may increase power consumption.
    """

    // periphery:ignore - Reserved: requireApproval static property — reserved for future feature activation
    static let requireApproval = """
    // periphery:ignore - Reserved: requireApproval static property reserved for future feature activation
    Require explicit approval before executing potentially destructive operations \
    like file deletion, code modification, or system changes.
    """

    // periphery:ignore - Reserved: enableRollback static property reserved for future feature activation
    static let enableRollback = """
    Create automatic backups before making changes, allowing you to undo operations \
    if something goes wrong.
    """
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Stream Responses")
            Spacer()
            Toggle("", isOn: .constant(true))
            HelpButton(
                title: "Stream Responses",
                explanation: SettingsHelpText.streamResponses
            )
        }
        .padding()

        HStack {
            Text("Enable iCloud Sync")
            Spacer()
            Toggle("", isOn: .constant(false))
            HelpButton(
                title: "iCloud Sync",
                explanation: SettingsHelpText.iCloudSync
            )
        }
        .padding()
    }
    .frame(width: 400)
}
