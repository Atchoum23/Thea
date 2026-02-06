//
//  APIBuilderView.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

// MARK: - API Builder View

/// Main view for building and managing APIs and MCP servers
public struct APIBuilderView: View {
    @State private var selectedTab: BuilderTab = .mcp
    @State private var mcpServers: [GeneratedMCPServer] = []
    @State private var apis: [GeneratedAPI] = []
    @State private var showNewMCPSheet = false
    @State private var showNewAPISheet = false
    @State private var showImportSheet = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List {
                Section("MCP Servers") {
                    ForEach(mcpServers) { server in
                        NavigationLink(value: BuilderItem.mcp(server)) {
                            GeneratedMCPServerRow(server: server)
                        }
                    }

                    Button {
                        showNewMCPSheet = true
                    } label: {
                        Label("New MCP Server", systemImage: "plus.circle")
                    }
                }

                Section("REST APIs") {
                    ForEach(apis) { api in
                        NavigationLink(value: BuilderItem.api(api)) {
                            APIRow(api: api)
                        }
                    }

                    Button {
                        showNewAPISheet = true
                    } label: {
                        Label("New API Client", systemImage: "plus.circle")
                    }
                }

                Section {
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import OpenAPI Spec", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("API Builder")
        } detail: {
            ContentUnavailableView(
                "Select an Item",
                systemImage: "curlybraces",
                description: Text("Choose an MCP server or API to view its details")
            )
        }
        .sheet(isPresented: $showNewMCPSheet) {
            NewMCPServerSheet { server in
                mcpServers.append(server)
            }
        }
        .sheet(isPresented: $showNewAPISheet) {
            NewAPISheet { api in
                apis.append(api)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportOpenAPISheet { api in
                apis.append(api)
            }
        }
    }
}

// MARK: - Builder Tab

private enum BuilderTab: String, CaseIterable {
    case mcp = "MCP Servers"
    case api = "REST APIs"
}

// MARK: - Builder Item

private enum BuilderItem: Hashable {
    case mcp(GeneratedMCPServer)
    case api(GeneratedAPI)

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .mcp(server):
            hasher.combine("mcp")
            hasher.combine(server.id)
        case let .api(api):
            hasher.combine("api")
            hasher.combine(api.id)
        }
    }

    static func == (lhs: BuilderItem, rhs: BuilderItem) -> Bool {
        switch (lhs, rhs) {
        case let (.mcp(a), .mcp(b)):
            a.id == b.id
        case let (.api(a), .api(b)):
            a.id == b.id
        default:
            false
        }
    }
}

// MARK: - MCP Server Row

private struct GeneratedMCPServerRow: View {
    let server: GeneratedMCPServer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(server.name)
                .fontWeight(.medium)

            HStack {
                Label("\(server.spec.tools.count) tools", systemImage: "wrench")
                Label("\(server.spec.resources.count) resources", systemImage: "doc")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - API Row

private struct APIRow: View {
    let api: GeneratedAPI

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(api.name)
                .fontWeight(.medium)

            HStack {
                Label("\(api.spec.endpoints.count) endpoints", systemImage: "arrow.left.arrow.right")
                Label("\(api.spec.models.count) models", systemImage: "cube")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New MCP Server Sheet

private struct NewMCPServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serverName = ""
    @State private var serverDescription = ""
    @State private var selectedTemplate: String?
    @State private var templates: [MCPTemplate] = []
    @State private var tools: [MCPToolSpec] = []
    @State private var showAddTool = false
    @State private var isGenerating = false

    let onGenerate: (GeneratedMCPServer) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Info") {
                    TextField("Server Name", text: $serverName)
                    TextField("Description", text: $serverDescription)
                }

                Section("Template (Optional)") {
                    Picker("Start from template", selection: $selectedTemplate) {
                        Text("None").tag(nil as String?)
                        ForEach(templates, id: \.name) { template in
                            Text(template.name).tag(template.name as String?)
                        }
                    }
                }

                Section("Tools") {
                    ForEach(tools) { tool in
                        VStack(alignment: .leading) {
                            Text(tool.name)
                                .fontWeight(.medium)
                            Text(tool.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        tools.remove(atOffsets: indexSet)
                    }

                    Button {
                        showAddTool = true
                    } label: {
                        Label("Add Tool", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New MCP Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        generateServer()
                    }
                    .disabled(serverName.isEmpty || isGenerating)
                }
            }
            .task {
                templates = await MCPServerGenerator.shared.getAvailableTemplates()
            }
            .sheet(isPresented: $showAddTool) {
                AddToolSheet { tool in
                    tools.append(tool)
                }
            }
            .onChange(of: selectedTemplate) { _, newValue in
                if let templateName = newValue,
                   let template = templates.first(where: { $0.name == templateName })
                {
                    tools = template.defaultTools
                }
            }
        }
    }

    private func generateServer() {
        isGenerating = true

        Task {
            let spec = MCPServerSpec(
                name: serverName,
                description: serverDescription,
                tools: tools
            )

            do {
                let server = try await MCPServerGenerator.shared.generateServer(from: spec)
                await MainActor.run {
                    onGenerate(server)
                    dismiss()
                }
            } catch {
                // Handle error
                isGenerating = false
            }
        }
    }
}

// MARK: - Add Tool Sheet

private struct AddToolSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toolName = ""
    @State private var toolDescription = ""
    @State private var parameters: [MCPParameterSpec] = []
    @State private var showAddParameter = false

    let onAdd: (MCPToolSpec) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Tool Info") {
                    TextField("Tool Name", text: $toolName)
                    TextField("Description", text: $toolDescription)
                }

                Section("Parameters") {
                    ForEach(parameters, id: \.name) { param in
                        VStack(alignment: .leading) {
                            Text(param.name)
                                .fontWeight(.medium)
                            Text("\(param.type.rawValue) - \(param.isRequired ? "Required" : "Optional")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        parameters.remove(atOffsets: indexSet)
                    }

                    Button {
                        showAddParameter = true
                    } label: {
                        Label("Add Parameter", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Add Tool")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let tool = MCPToolSpec(
                            name: toolName,
                            description: toolDescription,
                            parameters: parameters
                        )
                        onAdd(tool)
                        dismiss()
                    }
                    .disabled(toolName.isEmpty)
                }
            }
            .sheet(isPresented: $showAddParameter) {
                AddParameterSheet { param in
                    parameters.append(param)
                }
            }
        }
    }
}

// MARK: - Add Parameter Sheet

private struct AddParameterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var paramName = ""
    @State private var paramDescription = ""
    @State private var paramType: MCPParameterType = .string
    @State private var isRequired = true

    let onAdd: (MCPParameterSpec) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Parameter Name", text: $paramName)
                TextField("Description", text: $paramDescription)

                Picker("Type", selection: $paramType) {
                    ForEach([MCPParameterType.string, .number, .integer, .boolean, .array, .object], id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Toggle("Required", isOn: $isRequired)
            }
            .navigationTitle("Add Parameter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let param = MCPParameterSpec(
                            name: paramName,
                            type: paramType,
                            description: paramDescription,
                            isRequired: isRequired
                        )
                        onAdd(param)
                        dismiss()
                    }
                    .disabled(paramName.isEmpty)
                }
            }
        }
    }
}

// MARK: - New API Sheet

private struct NewAPISheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiName = ""
    @State private var baseURL = "https://api.example.com"
    @State private var selectedTemplate: String?
    @State private var templates: [APITemplate] = []
    @State private var endpoints: [APIEndpointSpec] = []
    @State private var isGenerating = false

    let onGenerate: (GeneratedAPI) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("API Info") {
                    TextField("API Name", text: $apiName)
                    TextField("Base URL", text: $baseURL)
                }

                Section("Template (Optional)") {
                    Picker("Start from template", selection: $selectedTemplate) {
                        Text("None").tag(nil as String?)
                        ForEach(templates, id: \.name) { template in
                            Text(template.name).tag(template.name as String?)
                        }
                    }
                }

                Section("Endpoints") {
                    ForEach(endpoints) { endpoint in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(endpoint.method)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                                Text(endpoint.path)
                            }
                            Text(endpoint.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New API Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        generateAPI()
                    }
                    .disabled(apiName.isEmpty || isGenerating)
                }
            }
            .task {
                templates = await APIGenerator.shared.getAvailableTemplates()
            }
            .onChange(of: selectedTemplate) { _, newValue in
                if let templateName = newValue,
                   let template = templates.first(where: { $0.name == templateName })
                {
                    endpoints = template.defaultEndpoints
                }
            }
        }
    }

    private func generateAPI() {
        isGenerating = true

        Task {
            let spec = APISpec(
                name: apiName,
                baseURL: baseURL,
                endpoints: endpoints
            )

            do {
                let api = try await APIGenerator.shared.generateAPI(from: spec)
                await MainActor.run {
                    onGenerate(api)
                    dismiss()
                }
            } catch {
                // Handle error
                isGenerating = false
            }
        }
    }
}

// MARK: - Import OpenAPI Sheet

private struct ImportOpenAPISheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var specText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    let onImport: (GeneratedAPI) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                Text("Paste your OpenAPI/Swagger specification (JSON format)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                TextEditor(text: $specText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                    .padding()

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Import OpenAPI")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importSpec()
                    }
                    .disabled(specText.isEmpty || isImporting)
                }
            }
        }
    }

    private func importSpec() {
        isImporting = true
        errorMessage = nil

        Task {
            guard let data = specText.data(using: .utf8) else {
                errorMessage = "Invalid text encoding"
                isImporting = false
                return
            }

            do {
                let api = try await APIGenerator.shared.generateFromOpenAPI(data)
                await MainActor.run {
                    onImport(api)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("API Builder") {
    APIBuilderView()
}
