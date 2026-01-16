import SwiftUI

// MARK: - MCP Tool List
// Displays tools available from a specific MCP server

struct MCPToolList: View {
    let server: MCPServerInfo
    @State private var tools: [MCPToolInfo] = []
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: serverIcon)
                        .font(.title)
                        .foregroundColor(.theaPrimary)
                    
                    VStack(alignment: .leading) {
                        Text(server.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(server.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(server.status.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Stats
                HStack(spacing: 16) {
                    Label("\(tools.count) tools", systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tools...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding()
            
            // Tool list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTools) { tool in
                        ToolCard(tool: tool)
                    }
                }
                .padding()
            }
        }
        .onAppear { loadTools() }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTools: [MCPToolInfo] {
        if searchText.isEmpty {
            return tools
        } else {
            return tools.filter { tool in
                tool.name.lowercased().contains(searchText.lowercased()) ||
                tool.description.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private var statusColor: Color {
        switch server.status {
        case .connected: return .green
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private var serverIcon: String {
        switch server.name.lowercased() {
        case "filesystem": return "folder.fill"
        case "terminal": return "terminal.fill"
        case "git": return "chevron.left.forwardslash.chevron.right"
        case "web": return "globe"
        default: return "server.rack"
        }
    }
    
    // MARK: - Actions
    
    private func loadTools() {
        // Load tools from MCP server
        // For now, use mock data based on server type
        switch server.name.lowercased() {
        case "filesystem":
            tools = [
                MCPToolInfo(
                    id: UUID(),
                    name: "read_file",
                    description: "Read contents of a file",
                    parameters: ["path"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "write_file",
                    description: "Write content to a file",
                    parameters: ["path", "content"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "list_directory",
                    description: "List files in a directory",
                    parameters: ["path"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "create_directory",
                    description: "Create a new directory",
                    parameters: ["path"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "delete_file",
                    description: "Delete a file or directory",
                    parameters: ["path"]
                )
            ]
            
        case "terminal":
            tools = [
                MCPToolInfo(
                    id: UUID(),
                    name: "execute",
                    description: "Execute a shell command",
                    parameters: ["command", "workingDirectory"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "spawn",
                    description: "Spawn a long-running process",
                    parameters: ["command", "args"]
                )
            ]
            
        case "git":
            tools = [
                MCPToolInfo(
                    id: UUID(),
                    name: "status",
                    description: "Get repository status",
                    parameters: ["repo"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "commit",
                    description: "Create a commit",
                    parameters: ["repo", "message"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "push",
                    description: "Push commits to remote",
                    parameters: ["repo", "remote", "branch"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "pull",
                    description: "Pull changes from remote",
                    parameters: ["repo", "remote", "branch"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "branch",
                    description: "Create or switch branch",
                    parameters: ["repo", "name"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "diff",
                    description: "Show file differences",
                    parameters: ["repo", "file"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "log",
                    description: "View commit history",
                    parameters: ["repo", "limit"]
                ),
                MCPToolInfo(
                    id: UUID(),
                    name: "clone",
                    description: "Clone a repository",
                    parameters: ["url", "destination"]
                )
            ]
            
        default:
            tools = []
        }
    }
}

// MARK: - Tool Card

private struct ToolCard: View {
    let tool: MCPToolInfo
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.theaPrimary)
                
                Text(tool.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(tool.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if isExpanded && !tool.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parameters:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(tool.parameters, id: \.self) { param in
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                            
                            Text(param)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    MCPToolList(server: MCPServerInfo(
        id: UUID(),
        name: "filesystem",
        description: "File system operations",
        status: .connected,
        toolCount: 5
    ))
    .frame(width: 600, height: 800)
}
