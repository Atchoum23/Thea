// DocumentSuiteView.swift
// Thea — AI-powered document creation UI
// Replaces: Microsoft Office (for creation/export)
//
// Document list, markdown editor, templates, export.

import SwiftUI

struct DocumentSuiteView: View {
    @State private var documents: [TheaDocument] = []
    @State private var selectedDocument: TheaDocument?
    @State private var editorContent = ""
    @State private var editorTitle = ""
    @State private var showTemplates = false
    @State private var showExport = false
    @State private var searchText = ""
    @State private var selectedType: DocSuiteType?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        #if os(macOS)
        HSplitView {
            documentList
                .frame(minWidth: 240, idealWidth: 280)
            editorPanel
                .frame(minWidth: 400)
        }
        .navigationTitle("Documents")
        .task { await loadDocuments() }
        #else
        NavigationStack {
            List {
                templateSection
                documentsSection
            }
            .navigationTitle("Documents")
            .task { await loadDocuments() }
            .searchable(text: $searchText, prompt: "Search documents")
        }
        #endif
    }

    // MARK: - macOS Layout

    #if os(macOS)
    private var documentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stats bar
            HStack {
                Label("\(documents.count)", systemImage: "doc.fill")
                Spacer()
                let words = documents.reduce(0) { $0 + $1.wordCount }
                Label("\(words) words", systemImage: "textformat.abc")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)

            Divider()

            // New document / template buttons
            HStack {
                Button {
                    Task { await createNewDocument() }
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    showTemplates = true
                } label: {
                    Label("Template", systemImage: "doc.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)

            // Search
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .accessibilityLabel("Search documents")

            // Document list
            List(selection: Binding(
                get: { selectedDocument?.id },
                set: { id in
                    if let id, let doc = documents.first(where: { $0.id == id }) {
                        selectDocument(doc)
                    }
                }
            )) {
                ForEach(filteredDocuments) { doc in
                    documentRow(doc)
                        .tag(doc.id)
                        .contextMenu {
                            Button {
                                Task {
                                    await DocumentSuiteService.shared.toggleFavorite(doc.id)
                                    await loadDocuments()
                                }
                            } label: {
                                Label(doc.isFavorite ? "Unfavorite" : "Favorite", systemImage: doc.isFavorite ? "star.slash" : "star")
                            }
                            Divider()
                            Button(role: .destructive) {
                                Task {
                                    await DocumentSuiteService.shared.deleteDocument(doc.id)
                                    if selectedDocument?.id == doc.id { selectedDocument = nil }
                                    await loadDocuments()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(.vertical)
        .sheet(isPresented: $showTemplates) {
            templatePicker
        }
    }

    private var editorPanel: some View {
        VStack(spacing: 0) {
            if selectedDocument != nil {
                // Toolbar
                HStack {
                    TextField("Title", text: $editorTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)
                        .accessibilityLabel("Document title")
                        .onChange(of: editorTitle) {
                            saveCurrentDocument()
                        }

                    Spacer()

                    Text("\(TheaDocument.countWords(editorContent)) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()

                Divider()

                // Editor
                TextEditor(text: $editorContent)
                    .font(.body)
                    .padding(8)
                    .onChange(of: editorContent) {
                        saveCurrentDocument()
                    }
                    .accessibilityLabel("Document content editor")
            } else {
                ContentUnavailableView(
                    "No Document Selected",
                    systemImage: "doc.text",
                    description: Text("Create a new document or select one from the list")
                )
            }
        }
        .sheet(isPresented: $showExport) {
            if let doc = selectedDocument {
                exportSheet(for: doc)
            }
        }
    }
    #endif

    // MARK: - iOS Sections

    // periphery:ignore - Reserved: templateSection property — reserved for future feature activation
    private var templateSection: some View {
        Section("Quick Start") {
            // periphery:ignore - Reserved: templateSection property reserved for future feature activation
            Button {
                Task { await createNewDocument() }
            } label: {
                Label("Blank Document", systemImage: "plus")
            }

            NavigationLink {
                templateListView
            } label: {
                Label("From Template", systemImage: "doc.badge.gearshape")
            }
        }
    }

    @ViewBuilder
    // periphery:ignore - Reserved: documentsSection property — reserved for future feature activation
    private var documentsSection: some View {
        // periphery:ignore - Reserved: documentsSection property reserved for future feature activation
        if documents.isEmpty {
            Section {
                Text("No documents yet")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Documents (\(filteredDocuments.count))") {
                ForEach(filteredDocuments) { doc in
                    NavigationLink {
                        iOSDocumentEditor(doc)
                    } label: {
                        documentRow(doc)
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let doc = filteredDocuments[index]
                            await DocumentSuiteService.shared.deleteDocument(doc.id)
                        }
                        await loadDocuments()
                    }
                }
            }
        }
    }

    // MARK: - Shared Components

    private func documentRow(_ doc: TheaDocument) -> some View {
        HStack {
            Image(systemName: doc.type.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(doc.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    if doc.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }
                }
                HStack {
                    Text("\(doc.wordCount) words")
                    Text("·")
                    Text(doc.modifiedAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var templatePicker: some View {
        NavigationStack {
            templateListView
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var templateListView: some View {
        List {
            ForEach(DocumentSuiteService.shared.templates) { template in
                Button {
                    Task {
                        do {
                            let doc = try await DocumentSuiteService.shared.createFromTemplate(template.name)
                            selectDocument(doc)
                            await loadDocuments()
                        } catch {
                            errorMessage = "Failed to create document: \(error.localizedDescription)"
                            showError = true
                        }
                        showTemplates = false
                    }
                } label: {
                    HStack {
                        Image(systemName: template.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(template.name)
                                .font(.subheadline)
                            Text(template.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Templates")
    }

    @ViewBuilder
    private func exportSheet(for doc: TheaDocument) -> some View {
        NavigationStack {
            List {
                ForEach(DocExportFormat.allCases, id: \.self) { format in
                    Button {
                        exportDocument(doc, format: format)
                    } label: {
                        Label(format.rawValue, systemImage: format.icon)
                    }
                }
            }
            .navigationTitle("Export As")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showExport = false }
                }
            }
            #endif
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    // periphery:ignore - Reserved: iOSDocumentEditor(_:) instance method reserved for future feature activation
    private func iOSDocumentEditor(_ doc: TheaDocument) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(doc.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showExport = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)
            }
            .padding(.horizontal)

            TextEditor(text: Binding(
                get: { doc.content },
                set: { newValue in
                    Task {
                        await DocumentSuiteService.shared.updateDocument(doc.id, content: newValue)
                        await loadDocuments()
                    }
                }
            ))
            .padding(8)
        }
        .navigationTitle(doc.title)
        .sheet(isPresented: $showExport) {
            exportSheet(for: doc)
        }
    }

    // MARK: - Actions

    private func createNewDocument() async {
        let doc = await DocumentSuiteService.shared.createDocument()
        selectDocument(doc)
        await loadDocuments()
    }

    private func selectDocument(_ doc: TheaDocument) {
        selectedDocument = doc
        editorContent = doc.content
        editorTitle = doc.title
    }

    private func saveCurrentDocument() {
        guard let doc = selectedDocument else { return }
        Task {
            await DocumentSuiteService.shared.updateDocument(doc.id, title: editorTitle, content: editorContent)
        }
    }

    private func loadDocuments() async {
        documents = await DocumentSuiteService.shared.getDocuments()
        // Refresh selected if it still exists
        if let sel = selectedDocument,
           let updated = documents.first(where: { $0.id == sel.id }) {
            selectedDocument = updated
        }
    }

    private func exportDocument(_ doc: TheaDocument, format: DocExportFormat) {
        Task {
            do {
                let data = try await DocumentSuiteService.shared.exportContent(doc.content, title: doc.title, format: format)
                #if os(macOS)
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "\(doc.title).\(format.fileExtension)"
                if panel.runModal() == .OK, let url = panel.url {
                    try data.write(to: url)
                }
                #endif
                showExport = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Helpers

    private var filteredDocuments: [TheaDocument] {
        var items = documents
        if let type = selectedType {
            items = items.filter { $0.type == type }
        }
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(lower) ||
                $0.content.lowercased().contains(lower)
            }
        }
        return items.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}
