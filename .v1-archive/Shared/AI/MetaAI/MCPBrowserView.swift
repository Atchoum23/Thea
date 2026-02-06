import SwiftUI

// MARK: - MCP Browser View

// Browse and inspect MCP servers and their tools

struct MCPBrowserView: View {
    @State private var servers: [MCPServerInfo] = []
    @State private var selectedServer: MCPServerInfo?

    var body: some View {
        NavigationSplitView {
            // Server list sidebar
            List(servers, selection: $selectedServer) { server in
                MCPServerRow(server: server)
                    .tag(server)
            }
            .navigationTitle("MCP Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: refreshServers) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            // Tool detail view
            if let server = selectedServer {
                MCPToolList(server: server)
            } else {
                ContentUnavailableView(
                    "No Server Selected",
                    systemImage: "server.rack",
                    description: Text("Select a server to view its tools")
                )
            }
        }
        .onAppear { loadServers() }
    }

    // MARK: - Actions

    private func loadServers() {
        servers = MCPToolRegistry.shared.mcpServers
        if servers.isEmpty {
            servers = [
                MCPServerInfo(
                    id: UUID(),
                    name: "filesystem",
                    description: "File system operations",
                    status: .connected,
                    toolCount: 5
                ),
                MCPServerInfo(
                    id: UUID(),
                    name: "terminal",
                    description: "Terminal command execution",
                    status: .connected,
                    toolCount: 2
                ),
                MCPServerInfo(
                    id: UUID(),
                    name: "git",
                    description: "Git repository operations",
                    status: .connected,
                    toolCount: 8
                )
            ]
        }
    }

    private func refreshServers() {
        Task {
            await MCPToolRegistry.shared.refreshTools()
            loadServers()
        }
    }
}

// MARK: - Preview

#Preview {
    MCPBrowserView()
        .frame(width: 800, height: 600)
}
