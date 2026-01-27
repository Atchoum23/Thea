import SwiftUI

// MARK: - MCP Server Row

// Displays a server in the sidebar list

struct MCPServerRow: View {
    let server: MCPServerInfo

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Server icon
            Image(systemName: serverIcon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Server details
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.headline)

                Text(server.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Tool count badge
            Text("\(server.toolCount)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(10)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch server.status {
        case .connected: .green
        case .disconnected: .gray
        case .error: .red
        }
    }

    private var serverIcon: String {
        switch server.name.lowercased() {
        case "filesystem": "folder"
        case "terminal": "terminal"
        case "git": "chevron.left.forwardslash.chevron.right"
        case "web": "globe"
        default: "server.rack"
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        MCPServerRow(server: MCPServerInfo(
            id: UUID(),
            name: "filesystem",
            description: "File system operations",
            status: .connected,
            toolCount: 5
        ))

        MCPServerRow(server: MCPServerInfo(
            id: UUID(),
            name: "terminal",
            description: "Terminal command execution",
            status: .disconnected,
            toolCount: 2
        ))

        MCPServerRow(server: MCPServerInfo(
            id: UUID(),
            name: "git",
            description: "Git repository operations",
            status: .error,
            toolCount: 8
        ))
    }
}
