// QRIntelligenceView.swift
// Thea — QR/barcode scanning UI
// Replaces: QR Capture

import SwiftUI

#if os(iOS)
import VisionKit
import OSLog

private let logger = Logger(subsystem: "ai.thea.app", category: "QRIntelligenceView")
#endif

struct QRIntelligenceView: View {
    @State private var qr = QRIntelligence.shared
    @State private var searchQuery = ""
    @State private var selectedCode: ScannedQRCode?
    @State private var manualInput = ""
    @State private var showManualInput = false
    #if os(iOS)
    @State private var showScanner = false
    #endif
    @State private var showFileImporter = false

    var body: some View {
        #if os(macOS)
        HSplitView {
            codeList
                .frame(minWidth: 250, maxWidth: 350)
            detailView
                .frame(minWidth: 400)
        }
        #else
        NavigationStack {
            codeList
                .navigationTitle("QR Scanner")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showScanner = true }) {
                            Image(systemName: "qrcode.viewfinder")
                        }
                    }
                }
                #if os(iOS)
                .sheet(isPresented: $showScanner) {
                    if DataScannerViewController.isSupported {
                        QRScannerSheet { content in
                            let code = qr.processRawContent(content)
                            selectedCode = code
                            showScanner = false
                        }
                    } else {
                        Text("Camera scanning not available on this device")
                            .padding()
                    }
                }
                #endif
        }
        #endif
    }

    // MARK: - Code List

    private var codeList: some View {
        VStack(spacing: 0) {
            // Input bar
            HStack {
                #if os(macOS)
                Button(action: { showFileImporter = true }) {
                    Label("Import Image", systemImage: "photo")
                }

                Button(action: { showManualInput.toggle() }) {
                    Label("Manual", systemImage: "text.cursor")
                }
                #endif
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if showManualInput {
                HStack {
                    TextField("Paste QR content...", text: $manualInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { processManual() }
                    Button("Parse") { processManual() }
                        .disabled(manualInput.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Search
            TextField("Search codes...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Stats
            HStack {
                Text("\(filteredCodes.count) codes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                let favorites = filteredCodes.filter(\.isFavorite).count
                if favorites > 0 {
                    Label("\(favorites) favorites", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            Divider()

            // Code list
            List(selection: Binding(
                get: { selectedCode?.id },
                set: { id in selectedCode = qr.scannedCodes.first { $0.id == id } }
            )) {
                ForEach(filteredCodes) { code in
                    codeRow(code)
                        .tag(code.id)
                        .contextMenu {
                            Button("Toggle Favorite") { qr.toggleFavorite(code.id) }
                            Button("Copy Content") { copyToClipboard(code.rawContent) }
                            Divider()
                            Button("Delete", role: .destructive) { qr.deleteCode(code) }
                        }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.png, .jpeg, .heic, .tiff]) { result in
            guard case .success(let url) = result else { return }
            Task { await scanImageFile(url) }
        }
    }

    private func codeRow(_ code: ScannedQRCode) -> some View {
        HStack {
            Image(systemName: code.contentType.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if code.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(code.displayTitle)
                        .font(.body)
                        .lineLimit(1)
                }
                HStack {
                    Text(code.contentType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    Text(code.scannedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail View

    private var detailView: some View {
        Group {
            if let code = selectedCode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Image(systemName: code.contentType.icon)
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading) {
                                Text(code.displayTitle)
                                    .font(.title2.bold())
                                Text(code.contentType.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { qr.toggleFavorite(code.id) }) {
                                Image(systemName: code.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(code.isFavorite ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()

                        // Raw content
                        GroupBox("Raw Content") {
                            Text(code.rawContent)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Parsed data
                        if !code.parsedData.isEmpty {
                            GroupBox("Parsed Data") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(code.parsedData.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                        HStack(alignment: .top) {
                                            Text(key.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 80, alignment: .trailing)
                                            Text(value)
                                                .font(.body)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                            }
                        }

                        // Actions
                        GroupBox("Actions") {
                            VStack(spacing: 8) {
                                ForEach(code.suggestedActions) { action in
                                    Button(action: { executeAction(action, code: code) }) {
                                        Label(action.label, systemImage: action.icon)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        // Metadata
                        HStack {
                            Text("Scanned: \(code.scannedAt, style: .date) \(code.scannedAt, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "Select a QR Code",
                    systemImage: "qrcode",
                    description: Text("Scan a QR code or import an image to get started")
                )
            }
        }
    }

    // MARK: - Helpers

    private var filteredCodes: [ScannedQRCode] {
        if searchQuery.isEmpty { return qr.scannedCodes }
        return qr.searchCodes(query: searchQuery)
    }

    private func processManual() {
        guard !manualInput.isEmpty else { return }
        let code = qr.processRawContent(manualInput)
        selectedCode = code
        manualInput = ""
        showManualInput = false
    }

    private func scanImageFile(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        #if os(macOS)
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        #else
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return
        }
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else { return }
        #endif

        if let code = await qr.scanImage(cgImage) {
            selectedCode = code
        }
    }

    private func executeAction(_ action: QRAction, code: ScannedQRCode) {
        switch action.actionType {
        case .copyToClipboard:
            let textToCopy: String
            switch code.contentType {
            case .wifi: textToCopy = code.parsedData["password"] ?? code.rawContent
            default: textToCopy = code.rawContent
            }
            copyToClipboard(textToCopy)

        case .openURL:
            if let url = URL(string: code.rawContent) {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }

        case .composeEmail:
            let address = code.parsedData["address"] ?? code.rawContent
            if let url = URL(string: "mailto:\(address)") {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }

        case .callPhone:
            let number = code.parsedData["number"] ?? code.rawContent
            if let url = URL(string: "tel:\(number)") {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }

        case .openMap:
            let lat = code.parsedData["latitude"] ?? ""
            let lon = code.parsedData["longitude"] ?? ""
            if let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)") {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }

        default:
            copyToClipboard(code.rawContent)
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - iOS Scanner Sheet

#if os(iOS)
@available(iOS 16.0, *)
struct QRScannerSheet: UIViewControllerRepresentable {
    let onDetected: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        do {
            try scanner.startScanning()
        } catch {
            logger.error("Failed to start QR scanner: \(error.localizedDescription)")
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDetected: onDetected)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onDetected: (String) -> Void
        private var hasDetected = false

        init(onDetected: @escaping (String) -> Void) {
            self.onDetected = onDetected
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasDetected else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue {
                    hasDetected = true
                    onDetected(payload)
                    return
                }
            }
        }
    }
}
#endif
