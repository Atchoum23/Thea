// DocumentScannerView.swift
// Thea — Document scanner UI for macOS and iOS
// Replaces: Adobe Scan
//
// macOS: Import from files (PDF, images) via NSOpenPanel
// iOS: Camera capture via VisionKit + file import
// Both: Document list, search, category filter, detail view with OCR text

import SwiftUI
#if canImport(VisionKit) && os(iOS)
import VisionKit
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Document Scanner View

struct DocumentScannerView: View {
    @State private var scanner = DocumentScanner.shared
    @State private var searchText = ""
    @State private var selectedCategory: DocumentCategory?
    @State private var selectedDocument: ScannedDocument?
    @State private var isImporting = false
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: UUID?
    @State private var errorMessage: String?
    #if os(iOS)
    @State private var showCameraScanner = false
    #endif

    private var filteredDocuments: [ScannedDocument] {
        var docs = scanner.documents
        if let category = selectedCategory {
            docs = docs.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            docs = scanner.search(query: searchText)
            if let category = selectedCategory {
                docs = docs.filter { $0.category == category }
            }
        }
        return docs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            statsBar

            Divider()

            // Main content
            #if os(macOS)
            macOSContent
            #else
            iOSContent
            #endif
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Delete Document", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { documentToDelete = nil }
            Button("Delete", role: .destructive) {
                if let id = documentToDelete {
                    scanner.deleteDocument(id)
                    if selectedDocument?.id == id { selectedDocument = nil }
                }
                documentToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this document? This cannot be undone.")
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            StatBadge(label: "Total", value: "\(scanner.totalDocuments)", icon: "doc.fill")
            StatBadge(label: "Favorites", value: "\(scanner.favoriteCount)", icon: "star.fill")

            if let topCategory = scanner.categoryCounts.first {
                StatBadge(
                    label: "Top Category",
                    value: "\(topCategory.0.rawValue) (\(topCategory.1))",
                    icon: topCategory.0.icon
                )
            }

            Spacer()

            if scanner.isProcessing {
                ProgressView()
                    .controlSize(.small)
                Text("Processing...")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - macOS Content

    #if os(macOS)
    private var macOSContent: some View {
        HSplitView {
            // Document list
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    categoryPicker
                    Spacer()
                    importButton
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                Divider()

                if filteredDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .frame(minWidth: 300, idealWidth: 350)

            // Detail
            if let doc = selectedDocument {
                DocumentDetailView(
                    document: doc,
                    scanner: scanner,
                    onUpdate: { updated in
                        scanner.updateDocument(updated)
                        selectedDocument = updated
                    },
                    onDelete: {
                        documentToDelete = doc.id
                        showDeleteConfirmation = true
                    }
                )
                .frame(minWidth: 400)
            } else {
                VStack {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a document to view details")
                        .font(.theaBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    #endif

    // MARK: - iOS Content

    #if os(iOS)
    private var iOSContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                if filteredDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .searchable(text: $searchText, prompt: "Search documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCameraScanner = true
                        } label: {
                            Label("Scan with Camera", systemImage: "camera.fill")
                        }
                        Button {
                            isImporting = true
                        } label: {
                            Label("Import File", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCameraScanner) {
                DocumentCameraScannerView { images in
                    Task { await processImages(images) }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .png, .jpeg, .tiff, .heic],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleFileImport(result) }
        }
    }
    #endif

    // MARK: - Shared Components

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(DocumentCategory.allCases) { cat in
                    let count = scanner.documentsForCategory(cat).count
                    if count > 0 {
                        FilterChip(
                            title: "\(cat.rawValue) (\(count))",
                            isSelected: selectedCategory == cat
                        ) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
        }
    }

    private var documentList: some View {
        List(selection: Binding(
            get: { selectedDocument?.id },
            set: { id in selectedDocument = filteredDocuments.first { $0.id == id } }
        )) {
            ForEach(filteredDocuments) { doc in
                DocumentRowView(document: doc)
                    .tag(doc.id)
                    .contextMenu {
                        Button {
                            scanner.toggleFavorite(doc.id)
                        } label: {
                            Label(
                                doc.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: doc.isFavorite ? "star.slash" : "star"
                            )
                        }
                        Divider()
                        Button(role: .destructive) {
                            documentToDelete = doc.id
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.inset)
        #if os(macOS)
        .searchable(text: $searchText, prompt: "Search documents")
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No documents yet" : "No matching documents")
                .font(.theaHeadline)
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "Import a PDF or scan a document to get started" : "Try a different search term")
                .font(.theaCaption1)
                .foregroundStyle(.tertiary)
            if searchText.isEmpty {
                importButton
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var importButton: some View {
        Button {
            isImporting = true
        } label: {
            Label("Import", systemImage: "doc.badge.plus")
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .png, .jpeg, .tiff],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleFileImport(result) }
        }
        #endif
    }

    // MARK: - File Import Handling

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    if url.pathExtension.lowercased() == "pdf" {
                        _ = try await scanner.processPDF(at: url)
                    } else {
                        let data = try Data(contentsOf: url)
                        _ = try await scanner.processImage(data: data, filename: url.deletingPathExtension().lastPathComponent)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    #if os(iOS)
    private func processImages(_ images: [Data]) async {
        for (index, imageData) in images.enumerated() {
            do {
                _ = try await scanner.processImage(data: imageData, filename: "scan-\(index + 1)")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    #endif
}

// MARK: - Document Row

private struct DocumentRowView: View {
    let document: ScannedDocument

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.category.icon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(document.title)
                        .font(.theaSubhead)
                        .lineLimit(1)
                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                HStack(spacing: 6) {
                    Text(document.category.rawValue)
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    if document.pageCount > 1 {
                        Text("\(document.pageCount) pages")
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                    }
                    if !document.amounts.isEmpty {
                        Text(document.amounts.first?.formatted ?? "")
                            .font(.theaCaption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            Text(formatDate(document.documentDate ?? document.createdAt))
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.category.rawValue) document: \(document.title)")
    }

    private var categoryColor: Color {
        switch document.category.color {
        case "blue": .blue
        case "green": .green
        case "purple": .purple
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "teal": .teal
        case "indigo": .indigo
        case "brown": .brown
        case "mint": .mint
        case "cyan": .cyan
        case "pink": .pink
        default: .secondary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            fmt.dateFormat = "HH:mm"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            fmt.dateFormat = "d MMM"
        } else {
            fmt.dateFormat = "d MMM yyyy"
        }
        return fmt.string(from: date)
    }
}

// MARK: - Document Detail View

private struct DocumentDetailView: View {
    let document: ScannedDocument
    let scanner: DocumentScanner
    var onUpdate: (ScannedDocument) -> Void
    var onDelete: () -> Void

    @State private var editingTitle = false
    @State private var titleText = ""
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Details").tag(0)
                    Text("OCR Text").tag(1)
                    if !document.amounts.isEmpty {
                        Text("Amounts (\(document.amounts.count))").tag(2)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case 0: detailsSection
                case 1: ocrTextSection
                case 2: amountsSection
                default: EmptyView()
                }
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: document.category.icon)
                    .font(.title2)

                if editingTitle {
                    TextField("Title", text: $titleText) {
                        var updated = document
                        updated.title = titleText
                        onUpdate(updated)
                        editingTitle = false
                    }
                    .textFieldStyle(.roundedBorder)
                } else {
                    Text(document.title)
                        .font(.theaTitle3)
                        .onTapGesture {
                            titleText = document.title
                            editingTitle = true
                        }
                        .accessibilityLabel("Document title: \(document.title)")
                        .accessibilityHint("Double tap to edit title")
                }

                Spacer()

                Button {
                    scanner.toggleFavorite(document.id)
                } label: {
                    Image(systemName: document.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(document.isFavorite ? Color.theaWarning : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(document.isFavorite ? "Remove from favorites" : "Add to favorites")
            }

            // Tags
            DocumentTagFlowLayout(spacing: 4) {
                ForEach(document.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.theaCaption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow("Category", value: document.category.rawValue)

            if let sender = document.sender {
                detailRow("Sender", value: sender)
            }

            if let date = document.documentDate {
                detailRow("Document Date", value: {
                    let f = DateFormatter()
                    f.dateStyle = .long
                    return f.string(from: date)
                }())
            }

            detailRow("Pages", value: "\(document.pageCount)")
            detailRow("Scanned", value: {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .short
                return f.string(from: document.createdAt)
            }())

            if let lang = document.ocrLanguage {
                detailRow("Language", value: lang)
            }

            Divider()

            Text("Summary")
                .font(.theaSubhead)
                .fontWeight(.semibold)
            Text(document.summary)
                .font(.theaBody)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    let text = scanner.exportAsText(document)
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    #elseif os(iOS)
                    UIPasteboard.general.string = text
                    #endif
                } label: {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var ocrTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Extracted Text")
                    .font(.theaSubhead)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(document.extractedText.count) characters")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }

            Text(document.extractedText)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Amounts")
                .font(.theaSubhead)
                .fontWeight(.semibold)

            ForEach(document.amounts) { amount in
                HStack {
                    Text(amount.formatted)
                        .font(.theaBody)
                        .fontWeight(.medium)
                    if let label = amount.label {
                        Text(label)
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.theaSubhead)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            Text(value)
                .font(.theaBody)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Flow Layout (for tags)

private struct DocumentTagFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.theaCaption1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.theaCaption1)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - iOS Camera Scanner

#if os(iOS)
struct DocumentCameraScannerView: UIViewControllerRepresentable {
    var onCapture: ([Data]) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        // Check if VNDocumentCameraViewController is available
        guard VNDocumentCameraViewController.isSupported else {
            let alert = UIAlertController(
                title: "Not Supported",
                message: "Document scanning is not available on this device.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            let nav = UINavigationController(rootViewController: UIViewController())
            return nav
        }

        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = context.coordinator
        let nav = UINavigationController(rootViewController: scannerVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        let onCapture: @Sendable ([Data]) -> Void

        init(onCapture: @escaping @Sendable ([Data]) -> Void) {
            self.onCapture = onCapture
        }

        @MainActor
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [Data] = []
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                if let data = image.pngData() {
                    images.append(data)
                }
            }
            onCapture(images)
            controller.dismiss(animated: true)
        }

        @MainActor
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        @MainActor
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}
#endif
