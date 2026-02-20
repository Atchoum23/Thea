// MCPServerBrowserView.swift
// Thea — MCP Server Browser
//
// Browse connected MCP servers, discover local servers, add new connections,
// and view available tools and resources per server.

import SwiftUI

// MARK: - MCP Server Browser View

@MainActor
struct MCPServerBrowserView: View {
    @State private var clientManager = MCPClientManager.shared
    @State private var showAddServer = false
    @State private var newServerURL = ""
    @State private var newServerName = ""
    @State private var selectedServer: ConnectedMCPServer?
    @State private var showURLError = false

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("MCP Servers")
                .toolbar { sidebarToolbar }
        } detail: {
            detailContent
        }
        .sheet(isPresented: $showAddServer) {
            addServerSheet
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectedServer) {
            if !clientManager.connectedServers.isEmpty {
                Section("Connected") {
                    ForEach(clientManager.connectedServers) { server in
                        ConnectedMCPServerRow(server: server)
                            .tag(server)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await clientManager.disconnect(server: server) }
                                } label: {
                                    Label("Disconnect", systemImage: "xmark.circle")
                                }
                            }
                    }
                }
            }

            Section("Discovered Locally") {
                if clientManager.isDiscovering {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Scanning ports…").foregroundStyle(.secondary)
                    }
                } else if clientManager.discoveredServers.isEmpty {
                    Text("No local servers found")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                } else {
                    ForEach(clientManager.discoveredServers) { server in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name).font(.body)
                                Text("localhost:\(server.port)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Connect") {
                                Task { await clientManager.connect(to: server.url, name: server.name) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Button {
                    Task { await clientManager.discoverLocalServers() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddServer = true
            } label: {
                Label("Add Server", systemImage: "plus")
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let server = selectedServer {
            MCPServerDetailView(server: server)
        } else {
            ContentUnavailableView(
                "No Server Selected",
                systemImage: "server.rack",
                description: Text("Select a connected server to view its tools and resources.")
            )
        }
    }

    // MARK: - Add Server Sheet

    private var addServerSheet: some View {
        VStack(spacing: 20) {
            Text("Add MCP Server").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL").font(.caption).foregroundStyle(.secondary)
                TextField("http://localhost:3000", text: $newServerURL)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    #endif

                if showURLError {
                    Text("Enter a valid URL (e.g. http://localhost:3000)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Name (optional)").font(.caption).foregroundStyle(.secondary)
                TextField("My MCP Server", text: $newServerName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    showAddServer = false
                    resetAddServerForm()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Connect") {
                    connectToNewServer()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }

    private func connectToNewServer() {
        guard let url = URL(string: newServerURL), url.scheme != nil else {
            showURLError = true
            return
        }
        showURLError = false
        let name = newServerName.isEmpty ? nil : newServerName
        showAddServer = false
        Task { await clientManager.connect(to: url, name: name) }
        resetAddServerForm()
    }

    private func resetAddServerForm() {
        newServerURL = ""
        newServerName = ""
        showURLError = false
    }
}

// MARK: - Connected MCP Server Row

struct ConnectedMCPServerRow: View {
    var server: ConnectedMCPServer

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name).font(.body)
                Group {
                    if server.isConnecting {
                        Text("Connecting…")
                    } else if server.isConnected {
                        Text("\(server.toolCount) tools • \(server.resourceCount) resources")
                    } else if let error = server.lastError {
                        Text(error).lineLimit(1)
                    } else {
                        Text("Disconnected")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if server.isConnecting {
                Spacer()
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        if server.isConnecting { return .orange }
        if server.isConnected { return .green }
        return .red
    }
}

// MARK: - MCP Server Detail View

struct MCPServerDetailView: View {
    var server: ConnectedMCPServer
    @State private var tools: [MCPToolSpec] = []
    @State private var resources: [MCPResourceSpec] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                serverHeader

                Divider()

                // Tools
                toolsSection

                // Resources
                if !resources.isEmpty {
                    Divider()
                    resourcesSection
                }
            }
            .padding()
        }
        .navigationTitle(server.name)
        .task {
            await loadCapabilities()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await MCPClientManager.shared.reconnect(server: server) }
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }
                .disabled(server.isConnecting)
            }
        }
    }

    private var serverHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(server.isConnected ? .green : .red).frame(width: 10, height: 10)
                    Text(server.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(server.isConnected ? .green : .red)
                }
                Text(server.url.absoluteString).font(.caption).foregroundStyle(.secondary)
                if let connectedAt = server.connectedAt {
                    Text("Connected \(connectedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(server.toolCount)").font(.title2.weight(.bold))
                Text("tools").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .trailing) {
                Text("\(server.resourceCount)").font(.title2.weight(.bold))
                Text("resources").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Available Tools", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            if isLoading {
                ProgressView()
            } else if tools.isEmpty {
                Text("No tools available").foregroundStyle(.secondary).font(.caption)
            } else {
                ForEach(tools) { tool in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.name)
                            .font(.system(.body, design: .monospaced).weight(.medium))
                        Text(tool.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Available Resources", systemImage: "cylinder.split.1x2")
                .font(.headline)

            ForEach(resources) { resource in
                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.name)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                    Text(resource.uri).font(.caption2).foregroundStyle(.tertiary)
                    if !resource.description.isEmpty {
                        Text(resource.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func loadCapabilities() async {
        guard server.isConnected else { return }
        isLoading = true
        defer { isLoading = false }
        tools = (try? await server.client.listTools()) ?? []
        resources = (try? await server.client.listResources()) ?? []
    }
}

// MARK: - Preview

#Preview {
    MCPServerBrowserView()
}
