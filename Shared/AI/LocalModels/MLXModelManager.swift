import Foundation
import Observation
#if os(macOS)
    import AppKit
#endif

// MARK: - MLX Model Manager

// Actor for managing MLX and GGUF model discovery, installation, and lifecycle
// Coordinates with MLXModelScanner for directory scanning

@MainActor
@Observable
final class MLXModelManager {
    static let shared = MLXModelManager()

    private(set) var scannedModels: [ScannedModel] = []
    private(set) var modelDirectories: [URL] = []
    private(set) var isScanning: Bool = false
    private(set) var lastScanDate: Date?
    private(set) var scanError: Error?

    private let scanner = MLXModelScanner.shared
    private let defaults = UserDefaults.standard
    private var scanTask: Task<Void, Never>?
    private(set) var isScanComplete = false

    private init() {
        loadModelDirectories()
        scanTask = Task {
            await refreshModels()
            isScanComplete = true
        }
    }

    /// Wait for initial model scan to complete
    func waitForScan() async {
        await scanTask?.value
    }

    // MARK: - Directory Management

    func addModelDirectory(_ url: URL) async {
        guard !modelDirectories.contains(url) else { return }

        modelDirectories.append(url)
        saveModelDirectories()

        // Scan the new directory
        await scanDirectory(url)
    }

    func removeModelDirectory(_ url: URL) async {
        modelDirectories.removeAll { $0 == url }
        saveModelDirectories()

        // Remove models from this directory
        scannedModels.removeAll { $0.path.path.hasPrefix(url.path) }
    }

    func getDefaultModelDirectory() -> URL {
        let config = AppConfiguration.shared.localModelConfig
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(config.sharedLLMsDirectory)
    }

    private func loadModelDirectories() {
        if let data = defaults.data(forKey: "MLXModelManager.directories"),
           let urls = try? JSONDecoder().decode([URL].self, from: data) // Safe: corrupt cache → use default HuggingFace directories in else branch
        {
            modelDirectories = urls
        } else {
            var defaults: [URL] = []

            // Standard HuggingFace cache (where `huggingface-cli download` stores models)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let hfHome = ProcessInfo.processInfo.environment["HF_HOME"]
                .map { URL(fileURLWithPath: $0) }
                ?? home.appendingPathComponent(".cache/huggingface")
            let hfHub = hfHome.appendingPathComponent("hub")
            if FileManager.default.fileExists(atPath: hfHub.path) {
                defaults.append(hfHub)
            }

            // SharedLLMs directory
            let sharedDir = getDefaultModelDirectory()
            if FileManager.default.fileExists(atPath: sharedDir.path) {
                defaults.append(sharedDir)
            }

            // User-configured MLX models path from Settings
            let userPath = SettingsManager.shared.mlxModelsPath
            if !userPath.isEmpty {
                let expanded = NSString(string: userPath).expandingTildeInPath
                let userURL = URL(fileURLWithPath: expanded)
                if FileManager.default.fileExists(atPath: userURL.path),
                   !defaults.contains(userURL)
                {
                    defaults.append(userURL)
                }
            }

            modelDirectories = defaults
        }
    }

    private func saveModelDirectories() {
        if let data = try? JSONEncoder().encode(modelDirectories) {
            defaults.set(data, forKey: "MLXModelManager.directories")
        }
    }

    // MARK: - Model Scanning

    func refreshModels() async {
        isScanning = true
        scanError = nil
        scannedModels.removeAll()

        for directory in modelDirectories {
            await scanDirectory(directory)
        }

        lastScanDate = Date()
        isScanning = false
    }

    private func scanDirectory(_ url: URL) async {
        do {
            let models = try await scanner.scanDirectory(url)
            scannedModels.append(contentsOf: models)
        } catch {
            print("⚠️ Failed to scan directory \(url.path): \(error)")
            scanError = error
        }
    }

    func quickScanCount() async -> Int {
        var total = 0
        for directory in modelDirectories {
            total += await scanner.quickScanCount(directory)
        }
        return total
    }

    // MARK: - Model Information

    func getModel(byID id: UUID) -> ScannedModel? {
        scannedModels.first { $0.id == id }
    }

    func getModel(byName name: String) -> ScannedModel? {
        scannedModels.first { $0.name == name }
    }

    func getModels(format: ModelFormat) -> [ScannedModel] {
        scannedModels.filter { $0.format == format }
    }

    func getTotalModelsSize() -> Int64 {
        scannedModels.reduce(0) { $0 + $1.sizeInBytes }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: getTotalModelsSize(), countStyle: .file)
    }

    // MARK: - Model Operations

    func deleteModel(_ model: ScannedModel) async throws {
        // Remove from file system
        try FileManager.default.removeItem(at: model.path)

        // Remove from scanned models
        scannedModels.removeAll { $0.id == model.id }
    }

    func openModelLocation(_ model: ScannedModel) {
        #if os(macOS)
            NSWorkspace.shared.selectFile(model.path.path, inFileViewerRootedAtPath: "")
        #endif
    }

    // MARK: - Directory Creation

    func createDefaultDirectoryIfNeeded() async throws {
        let defaultDir = getDefaultModelDirectory()

        if !FileManager.default.fileExists(atPath: defaultDir.path) {
            try FileManager.default.createDirectory(
                at: defaultDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Add to model directories
            await addModelDirectory(defaultDir)
        }
    }

    // MARK: - Model Import

    func importModel(from sourceURL: URL, to destinationDirectory: URL) async throws -> ScannedModel {
        let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw ModelManagerError.modelAlreadyExists
        }

        // Copy file
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // Scan the newly imported model
        let model = try await scanner.scanDirectory(destinationDirectory)
            .first { $0.path == destinationURL }

        guard let importedModel = model else {
            throw ModelManagerError.importFailed
        }

        // Add to scanned models if not already there
        if !scannedModels.contains(where: { $0.id == importedModel.id }) {
            scannedModels.append(importedModel)
        }

        return importedModel
    }

    // MARK: - Statistics

    func getStatistics() -> ModelStatistics {
        let mlxCount = scannedModels.count { $0.format == .mlx }
        let ggufCount = scannedModels.count { $0.format == .gguf }
        let totalSize = getTotalModelsSize()

        return ModelStatistics(
            totalModels: scannedModels.count,
            mlxModels: mlxCount,
            ggufModels: ggufCount,
            totalSizeBytes: totalSize,
            directories: modelDirectories.count,
            lastScanDate: lastScanDate
        )
    }
}

// MARK: - Data Structures

struct ModelStatistics {
    let totalModels: Int
    let mlxModels: Int
    let ggufModels: Int
    let totalSizeBytes: Int64
    let directories: Int
    let lastScanDate: Date?

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    var isEmpty: Bool {
        totalModels == 0
    }
}

// MARK: - Errors

enum ModelManagerError: LocalizedError {
    case modelAlreadyExists
    case importFailed
    case invalidModelPath

    var errorDescription: String? {
        switch self {
        case .modelAlreadyExists:
            "A model with this name already exists"
        case .importFailed:
            "Failed to import model"
        case .invalidModelPath:
            "Invalid model path"
        }
    }
}
