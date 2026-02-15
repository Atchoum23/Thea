// ImageIntelligenceView.swift
// Thea — AI-powered image processing UI
// Replaces: Pixelmator Pro (for quick AI-assisted edits)
//
// File import, operation selection, preview, processing history.

import SwiftUI

struct ImageIntelligenceView: View {
    @State private var selectedOperation: ImageOperation = .analyzeContent
    @State private var analysisResult: ImageAnalysisResult?
    @State private var processingHistory: [ImageProcessingRecord] = []
    @State private var isProcessing = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedFormat: ImageFormat = .jpeg
    @State private var compressionQuality: Double = 0.85
    @State private var targetWidth: String = "1920"
    @State private var targetHeight: String = "1080"
    @State private var colorAdjustment = ColorAdjustment.identity
    @State private var processedImageData: Data?
    @State private var selectedImageURL: URL?

    var body: some View {
        #if os(macOS)
        HSplitView {
            operationPanel
                .frame(minWidth: 280, idealWidth: 320)
            resultPanel
                .frame(minWidth: 400)
        }
        .navigationTitle("Image Intelligence")
        .task { await loadHistory() }
        #else
        NavigationStack {
            List {
                operationSection
                historySection
            }
            .navigationTitle("Image Intelligence")
            .task { await loadHistory() }
        }
        #endif
    }

    // MARK: - macOS Panels

    #if os(macOS)
    private var operationPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats bar
            HStack {
                Label("\(processingHistory.count)", systemImage: "photo.stack")
                Spacer()
                if let totalSaved = totalBytesSaved(), totalSaved > 0 {
                    Label(imageFormatFileSize(Int64(totalSaved)), systemImage: "arrow.down.circle")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)
            .padding(.horizontal)

            Divider()

            // Import button
            Button {
                isImporting = true
            } label: {
                Label("Import Image", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.png, .jpeg, .heic, .tiff, .image],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }

            if let url = selectedImageURL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal)
            }

            Divider()

            // Operation picker
            Text("Operation")
                .font(.headline)
                .padding(.horizontal)

            Picker("Operation", selection: $selectedOperation) {
                ForEach(ImageOperation.allCases, id: \.self) { op in
                    Label(op.rawValue, systemImage: op.icon).tag(op)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .accessibilityLabel("Image operation")

            // Operation-specific controls
            operationControls
                .padding(.horizontal)

            Spacer()

            // Process button
            Button {
                Task { await processImage() }
            } label: {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Process", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImageURL == nil || isProcessing)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.vertical)
    }

    private var resultPanel: some View {
        VStack {
            if let result = analysisResult {
                analysisResultView(result)
            } else if let imageData = processedImageData {
                processedImageView(imageData)
            } else if processingHistory.isEmpty {
                ContentUnavailableView(
                    "No Images Processed",
                    systemImage: "photo.artframe",
                    description: Text("Import an image and select an operation to get started")
                )
            } else {
                historyListView
            }
        }
    }
    #endif

    // MARK: - Operation Controls

    @ViewBuilder
    private var operationControls: some View {
        switch selectedOperation {
        case .convertFormat:
            Picker("Target Format", selection: $selectedFormat) {
                ForEach(ImageFormat.allCases, id: \.self) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .accessibilityLabel("Target image format")

        case .compress:
            VStack(alignment: .leading) {
                Text("Quality: \(Int(compressionQuality * 100))%")
                    .font(.caption)
                Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.05)
                    .accessibilityLabel("Compression quality")
            }

        case .resize:
            HStack {
                TextField("Width", text: $targetWidth)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .accessibilityLabel("Target width")
                Text("×")
                TextField("Height", text: $targetHeight)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .accessibilityLabel("Target height")
            }

        case .adjustColors:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brightness")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $colorAdjustment.brightness, in: -1.0...1.0)
                        .accessibilityLabel("Brightness")
                }
                HStack {
                    Text("Contrast")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $colorAdjustment.contrast, in: 0.0...4.0)
                        .accessibilityLabel("Contrast")
                }
                HStack {
                    Text("Saturation")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $colorAdjustment.saturation, in: 0.0...2.0)
                        .accessibilityLabel("Saturation")
                }
                HStack {
                    Text("Sharpness")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $colorAdjustment.sharpness, in: 0.0...1.0)
                        .accessibilityLabel("Sharpness")
                }
                Button("Reset") {
                    colorAdjustment = .identity
                }
                .font(.caption)
            }
            .font(.caption)

        default:
            EmptyView()
        }
    }

    // MARK: - iOS Sections

    private var operationSection: some View {
        Section("Operations") {
            Button {
                isImporting = true
            } label: {
                Label("Import Image", systemImage: "photo.badge.plus")
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.png, .jpeg, .heic, .tiff, .image],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }

            if let url = selectedImageURL {
                HStack {
                    Text(url.lastPathComponent)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            ForEach(ImageOperation.allCases, id: \.self) { op in
                Button {
                    selectedOperation = op
                    Task { await processImage() }
                } label: {
                    Label(op.rawValue, systemImage: op.icon)
                }
                .disabled(selectedImageURL == nil || isProcessing)
            }
        }
    }

    private var historySection: some View {
        Section("Recent Operations") {
            if processingHistory.isEmpty {
                Text("No images processed yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(processingHistory.suffix(20).reversed()) { record in
                    HStack {
                        Image(systemName: record.operation.icon)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading) {
                            Text(record.fileName)
                                .font(.subheadline)
                            Text("\(record.operation.rawValue) — \(record.formattedInputSize) → \(record.formattedOutputSize)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Result Views

    private func analysisResultView(_ result: ImageAnalysisResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Dimensions
                GroupBox("Image Info") {
                    VStack(alignment: .leading, spacing: 4) {
                        infoRow("Dimensions", result.dimensions.displayString)
                        infoRow("Megapixels", String(format: "%.1f MP", result.dimensions.megapixels))
                        infoRow("File Size", imageFormatFileSize(result.fileSize))
                        infoRow("Format", result.format.uppercased())
                        if result.faceCount > 0 {
                            infoRow("Faces Detected", "\(result.faceCount)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Scene classification
                if let scene = result.sceneClassification {
                    GroupBox("Scene") {
                        Text(scene.capitalized)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Detected objects
                if !result.detectedObjects.isEmpty {
                    GroupBox("Detected Objects") {
                        ForEach(result.detectedObjects) { obj in
                            HStack {
                                Text(obj.label.capitalized)
                                Spacer()
                                Text("\(Int(obj.confidence * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Dominant colors
                if !result.dominantColors.isEmpty {
                    GroupBox("Dominant Colors") {
                        ForEach(result.dominantColors) { color in
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(red: color.red, green: color.green, blue: color.blue))
                                    .frame(width: 24, height: 24)
                                Text(color.hexString)
                                    .font(.monospaced(.body)())
                                Spacer()
                                Text("\(Int(color.percentage * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // OCR text
                if let text = result.textContent, !text.isEmpty {
                    GroupBox("Extracted Text") {
                        Text(text)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }

    private func processedImageView(_ data: Data) -> some View {
        VStack {
            #if os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            #endif

            HStack {
                Text("\(imageFormatFileSize(Int64(data.count)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Save") {
                    saveProcessedImage(data)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private var historyListView: some View {
        List(processingHistory.suffix(50).reversed()) { record in
            HStack {
                Image(systemName: record.operation.icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text(record.fileName)
                        .font(.subheadline)
                    Text("\(record.operation.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(record.formattedInputSize)
                        .font(.caption)
                    if record.compressionRatio > 0 {
                        Text("-\(Int(record.compressionRatio * 100))%")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedImageURL = urls.first
            analysisResult = nil
            processedImageData = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func processImage() async {
        guard let url = selectedImageURL else { return }
        isProcessing = true
        analysisResult = nil
        processedImageData = nil

        do {
            switch selectedOperation {
            case .analyzeContent:
                analysisResult = try await ImageIntelligence.shared.analyzeImage(at: url)
            case .extractText:
                let text = try await ImageIntelligence.shared.extractText(from: url)
                analysisResult = ImageAnalysisResult(textContent: text)
            case .convertFormat:
                let result = try await ImageIntelligence.shared.convertFormat(at: url, to: selectedFormat, quality: compressionQuality)
                processedImageData = result.data
            case .compress:
                let result = try await ImageIntelligence.shared.compress(at: url, quality: compressionQuality)
                processedImageData = result.data
            case .resize:
                let w = Int(targetWidth) ?? 1920
                let h = Int(targetHeight) ?? 1080
                let result = try await ImageIntelligence.shared.resize(at: url, to: ImageDimensions(width: w, height: h))
                processedImageData = result.data
            case .adjustColors:
                let result = try await ImageIntelligence.shared.adjustColors(at: url, adjustment: colorAdjustment)
                processedImageData = result.data
            case .generateThumbnail:
                let result = try await ImageIntelligence.shared.generateThumbnail(at: url)
                processedImageData = result.data
            case .removeBackground:
                #if os(macOS)
                let result = try await ImageIntelligence.shared.removeBackground(at: url)
                processedImageData = result.data
                #else
                errorMessage = "Background removal is only available on macOS"
                showError = true
                #endif
            case .crop:
                errorMessage = "Interactive crop is not yet available"
                showError = true
            case .upscale:
                errorMessage = "AI upscaling requires local ML model"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        await loadHistory()
        isProcessing = false
    }

    private func loadHistory() async {
        processingHistory = await ImageIntelligence.shared.getHistory()
    }

    private func totalBytesSaved() -> Int64? {
        let saved = processingHistory.reduce(Int64(0)) { $0 + max(0, $1.inputSize - $1.outputSize) }
        return saved > 0 ? saved : nil
    }

    private func saveProcessedImage(_ data: Data) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "processed_image"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
        #endif
    }
}
