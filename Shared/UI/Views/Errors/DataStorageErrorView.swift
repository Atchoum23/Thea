import SwiftUI

/// View displayed when data storage initialization fails completely
struct DataStorageErrorView: View {
    let error: Error?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            VStack(spacing: 12) {
                Text("Data Storage Error")
                    .font(.title.bold())

                Text("Thea was unable to initialize its data storage system.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = error {
                GroupBox {
                    ScrollView {
                        Text(error.localizedDescription)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                } label: {
                    Label("Error Details", systemImage: "info.circle")
                        .font(.caption.bold())
                }
                .frame(maxWidth: 400)
            }

            VStack(spacing: 12) {
                Text("Troubleshooting Steps:")
                    .font(.caption.bold())

                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Restart Thea and try again")
                    BulletPoint("Check available disk space")
                    BulletPoint("Ensure Thea has file system permissions")
                    BulletPoint("Try resetting application data")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            .frame(maxWidth: 400)

            HStack(spacing: 16) {
                Button(action: restart) {
                    Label("Restart App", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Button(action: reportIssue) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.bordered)

                Button(action: quit) {
                    Text("Quit")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            #else
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            #endif
        }
    }

    private func restart() {
        #if os(macOS)
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [Bundle.main.bundlePath]
        task.launch()
        NSApplication.shared.terminate(nil)
        #elseif os(iOS)
        // iOS doesn't allow programmatic app termination
        // User must manually restart
        #endif
    }

    private func reportIssue() {
        if let url = URL(string: "https://github.com/Atchoum23/Thea/issues/new") {
            openURL(url)
        }
    }

    private func quit() {
        #if os(macOS)
        NSApplication.shared.terminate(nil)
        #elseif os(iOS)
        // iOS doesn't allow programmatic termination
        #endif
    }
}

/// Helper view for bullet points
private struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .fontWeight(.bold)
            Text(text)
        }
    }
}

#Preview {
    DataStorageErrorView(error: ModelContainerError.initializationFailed(
        persistentError: NSError(domain: "com.thea", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disk full"]),
        fallbackError: NSError(domain: "com.thea", code: 2, userInfo: [NSLocalizedDescriptionKey: "Memory allocation failed"])
    ))
}
