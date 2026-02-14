import SwiftUI

struct iOSAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(.theaPrimary)

                    VStack(spacing: 8) {
                        Text("THEA")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your AI Life Companion")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 16) {
                        InfoRow(label: "Version", value: "1.0.0")
                        InfoRow(label: "Build", value: "2026.01.29")
                        InfoRow(label: "Platform", value: "iOS")
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 16) {
                        Text("Features")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        FeatureRow(icon: "message.fill", title: "Multi-Provider AI", description: "Support for OpenAI, Anthropic, Google, and more")
                        FeatureRow(icon: "mic.fill", title: "Voice Activation", description: "Hands-free interaction with wake word")
                        FeatureRow(icon: "brain.head.profile", title: "Knowledge Base", description: "Semantic search across your entire Mac")
                        FeatureRow(icon: "dollarsign.circle.fill", title: "Financial Insights", description: "AI-powered budget recommendations")
                        FeatureRow(icon: "terminal.fill", title: "Code Intelligence", description: "Multi-file context and Git integration")
                        FeatureRow(icon: "arrow.down.doc.fill", title: "Easy Migration", description: "Import from Claude, ChatGPT, Cursor")
                    }

                    VStack(spacing: 12) {
                        Text("Made with ❤️ for teathe.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("© 2026 THEA. All rights reserved.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.theaPrimary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
