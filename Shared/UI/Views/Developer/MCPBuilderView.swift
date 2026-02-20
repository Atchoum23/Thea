// MCPBuilderView.swift
// Visual builder for creating MCP server projects — Phase S3

import SwiftUI

// MARK: - MCP Builder View

/// Visual MCP server builder — point-and-click MCP server creation from Thea.
struct MCPBuilderView: View {
    @State private var serverName = ""
    @State private var serverDescription = ""
    @State private var tools: [EditableMCPTool] = []
    @State private var selectedTemplate: MCPTemplate?
    @State private var generatedServer: GeneratedMCPServer?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    @State private var showingPreview = false
    @State private var availableTemplates: [MCPTemplate] = []

    private let generator = MCPServerGenerator.shared

    var body: some View {
        Form {
            serverInfoSection
            templateSection
            toolsSection
            generateSection
        }
        .navigationTitle("MCP Server Builder")
        .sheet(item: $generatedServer) { server in
            GeneratedServerPreview(server: server)
        }
        .alert("Generation Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await generator.initialize()
            availableTemplates = await generator.getAvailableTemplates()
        }
    }

    // MARK: - Sections

    private var serverInfoSection: some View {
        Section("Server Info") {
            LabeledContent("Name") {
                TextField("my-mcp-server", text: $serverName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }
            LabeledContent("Description") {
                TextField("What does this server do?", text: $serverDescription)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            }
        }
    }

    private var templateSection: some View {
        Section("Template (Optional)") {
            Picker("Start from template", selection: $selectedTemplate) {
                Text("Custom (blank)").tag(nil as MCPTemplate?)
                ForEach(availableTemplates, id: \.name) { template in
                    VStack(alignment: .leading) {
                        Text(template.name)
                        Text(template.description).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(template as MCPTemplate?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedTemplate) { _, template in
                if let template {
                    applyTemplate(template)
                }
            }
        }
    }

    private var toolsSection: some View {
        Section("Tools (\(tools.count))") {
            if tools.isEmpty {
                Text("No tools defined — add tools below or choose a template.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach($tools) { $tool in
                    EditableMCPToolRow(tool: $tool)
                }
                .onDelete { indexSet in
                    tools.remove(atOffsets: indexSet)
                }
            }
            Button {
                tools.append(EditableMCPTool())
            } label: {
                Label("Add Tool", systemImage: "plus")
            }
        }
    }

    private var generateSection: some View {
        Section {
            HStack {
                Button {
                    Task { await generateServer() }
                } label: {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                        Text("Generating…")
                    } else {
                        Label("Generate Server", systemImage: "hammer.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverName.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)

                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func applyTemplate(_ template: MCPTemplate) {
        var config = MCPTemplateConfig(serverName: serverName.isEmpty ? template.name : serverName)
        config.includeDefaultResources = false
        config.includeDefaultPrompts = false
        let spec = template.createSpec(with: config)
        tools = spec.tools.map { EditableMCPTool(from: $0) }
        if serverDescription.isEmpty {
            serverDescription = template.description
        }
    }

    private func generateServer() async {
        isGenerating = true
        defer { isGenerating = false }

        let spec = MCPServerSpec(
            name: serverName.trimmingCharacters(in: .whitespaces),
            description: serverDescription,
            tools: tools.map(\.toSpec)
        )

        do {
            generatedServer = try await generator.generateServer(from: spec)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Editable Tool Row

private struct EditableMCPToolRow: View {
    @Binding var tool: EditableMCPTool
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("tool-name", text: $tool.name)
                        .font(.body.monospaced())
                    TextField("Description", text: $tool.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parameters").font(.caption).foregroundStyle(.secondary)
                    ForEach($tool.parameters) { $param in
                        HStack(spacing: 8) {
                            TextField("name", text: $param.name)
                                .frame(width: 100)
                                .font(.caption.monospaced())
                            Picker("", selection: $param.type) {
                                ForEach(MCPParameterType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .frame(width: 80)
                            TextField("description", text: $param.description)
                                .font(.caption)
                            Toggle("Req", isOn: $param.isRequired)
                                // .toggleStyle(.checkbox) // macOS only
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif
                                .labelsHidden()
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in tool.parameters.remove(atOffsets: indexSet) }

                    Button("Add Parameter", systemImage: "plus") {
                        tool.parameters.append(EditableMCPParam())
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Generated Server Preview

struct GeneratedServerPreview: View {
    let server: GeneratedMCPServer
    @State private var showCopied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    GroupBox("Server Info") {
                        LabeledContent("Name", value: server.name)
                        LabeledContent("Tools", value: "\(server.spec.tools.count)")
                        LabeledContent("Generated", value: server.generatedAt.formatted(.dateTime))
                    }

                    // Generated code
                    GroupBox("Generated Swift Code") {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(server.generatedCode)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 400)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding()
            }
            .navigationTitle("Generated: \(server.name)")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(server.generatedCode, forType: .string)
                        #else
                        UIPasteboard.general.string = server.generatedCode
                        #endif
                        showCopied = true
                        Task { try? await Task.sleep(for: .seconds(2)); showCopied = false }
                    } label: {
                        Label(showCopied ? "Copied!" : "Copy Code", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - Editable Model Types

struct EditableMCPTool: Identifiable {
    let id = UUID()
    var name: String = ""
    var description: String = ""
    var parameters: [EditableMCPParam] = []

    init() {}

    init(from spec: MCPToolSpec) {
        name = spec.name
        description = spec.description
        parameters = spec.parameters.map { EditableMCPParam(from: $0) }
    }

    var toSpec: MCPToolSpec {
        MCPToolSpec(
            name: name,
            description: description,
            parameters: parameters.map(\.toSpec)
        )
    }
}

struct EditableMCPParam: Identifiable {
    let id = UUID()
    var name: String = ""
    var type: MCPParameterType = .string
    var description: String = ""
    var isRequired: Bool = true

    init() {}

    init(from spec: MCPParameterSpec) {
        name = spec.name
        type = spec.type
        description = spec.description
        isRequired = spec.isRequired
    }

    var toSpec: MCPParameterSpec {
        MCPParameterSpec(name: name, type: type, description: description, isRequired: isRequired)
    }
}

extension MCPParameterType: CaseIterable {
    public static var allCases: [MCPParameterType] {
        [.string, .number, .integer, .boolean, .array, .object]
    }
}

#if DEBUG
#Preview {
    MCPBuilderView()
        .frame(width: 700, height: 600)
}
#endif
