import Foundation

// MARK: - MLX Model Scanner

// Scans directories for MLX and GGUF model files
// Extracts metadata like size, format, quantization

actor MLXModelScanner {
    static let shared = MLXModelScanner()

    private init() {}

    // MARK: - Scanning

    /// Scans a directory for MLX and GGUF model files
    func scanDirectory(_ url: URL) async throws -> [ScannedModel] {
        var models: [ScannedModel] = []

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScannerError.directoryNotFound(url.path)
        }

        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            // Check if it's a model file
            if isModelFile(fileURL) {
                if let model = try? await extractModelInfo(from: fileURL) {
                    models.append(model)
                }
            }
        }

        return models.sorted { $0.name < $1.name }
    }

    /// Quick scan for model count (doesn't extract full metadata)
    func quickScanCount(_ url: URL) async -> Int {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }

        var count = 0
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if isModelFile(fileURL) {
                count += 1
            }
        }

        return count
    }

    // MARK: - Model File Detection

    private func isModelFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()

        // Check for GGUF files
        if ext == "gguf" {
            return true
        }

        // Check for MLX model directories (typically contain config.json and weights)
        if let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
           isDirectory
        {
            return isMLXModelDirectory(url)
        }

        return false
    }

    private func isMLXModelDirectory(_ url: URL) -> Bool {
        // MLX models typically have:
        // - config.json
        // - tokenizer.json or tokenizer_config.json
        // - weights.safetensors or .npz files

        let requiredFiles = ["config.json"]
        let optionalMLXFiles = [
            "weights.safetensors",
            "model.safetensors",
            "tokenizer.json",
            "tokenizer_config.json"
        ]

        // Check for required files
        for required in requiredFiles {
            let path = url.appendingPathComponent(required)
            if !FileManager.default.fileExists(atPath: path.path) {
                return false
            }
        }

        // Check for at least one optional MLX file
        for optional in optionalMLXFiles {
            let path = url.appendingPathComponent(optional)
            if FileManager.default.fileExists(atPath: path.path) {
                return true
            }
        }

        return false
    }

    // MARK: - Metadata Extraction

    private func extractModelInfo(from url: URL) async throws -> ScannedModel {
        if url.pathExtension.lowercased() == "gguf" {
            try await extractGGUFInfo(from: url)
        } else {
            try await extractMLXInfo(from: url)
        }
    }

    private func extractGGUFInfo(from url: URL) async throws -> ScannedModel {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = resourceValues.fileSize ?? 0
        let modifiedDate = resourceValues.contentModificationDate ?? Date()

        // Extract quantization and parameters from filename
        // Common patterns: "llama-3.1-8b-instruct-q4_k_m.gguf"
        let filename = url.deletingPathExtension().lastPathComponent
        let (parameters, quantization) = parseModelName(filename)

        return ScannedModel(
            id: UUID(),
            name: filename,
            path: url,
            format: .gguf,
            sizeInBytes: Int64(size),
            parameters: parameters,
            quantization: quantization,
            modifiedDate: modifiedDate,
            status: .downloaded
        )
    }

    private func extractMLXInfo(from url: URL) async throws -> ScannedModel {
        let name = url.lastPathComponent

        // Calculate directory size
        let size = await calculateDirectorySize(url)

        // Try to read config.json for model info
        let configURL = url.appendingPathComponent("config.json")
        var parameters: String?
        var quantization: String?

        if FileManager.default.fileExists(atPath: configURL.path),
           let data = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            // Extract model parameters if available
            if let hiddenSize = json["hidden_size"] as? Int {
                parameters = formatParameters(hiddenSize: hiddenSize)
            }

            // Check for quantization info
            if let dtype = json["torch_dtype"] as? String {
                quantization = dtype
            }
        }

        // Fallback to parsing from directory name
        if parameters == nil || quantization == nil {
            let (parsedParams, parsedQuant) = parseModelName(name)
            parameters = parameters ?? parsedParams
            quantization = quantization ?? parsedQuant
        }

        let modifiedDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        return ScannedModel(
            id: UUID(),
            name: name,
            path: url,
            format: .mlx,
            sizeInBytes: size,
            parameters: parameters,
            quantization: quantization,
            modifiedDate: modifiedDate ?? Date(),
            status: .downloaded
        )
    }

    // MARK: - Utilities

    private func calculateDirectorySize(_ url: URL) async -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        // Convert to array first to avoid makeIterator in async context
        let allObjects = enumerator.allObjects
        for case let fileURL as URL in allObjects {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }

    private func parseModelName(_ name: String) -> (parameters: String?, quantization: String?) {
        let lowercased = name.lowercased()

        // Extract parameters (e.g., "7b", "13b", "70b")
        var parameters: String?
        if let range = lowercased.range(of: #"(\d+)b"#, options: .regularExpression) {
            let match = lowercased[range]
            let digits = match.replacingOccurrences(of: "b", with: "")
            parameters = "\(digits.uppercased())B"
        }

        // Extract quantization (e.g., "q4_k_m", "4bit", "fp16")
        var quantization: String?
        let quantPatterns = [
            #"q(\d+)_k_m"#, // q4_k_m
            #"q(\d+)_\d+"#, // q4_0
            #"(\d+)bit"#, // 4bit
            #"(fp\d+)"#, // fp16, fp32
            #"(int\d+)"# // int8, int4
        ]

        for pattern in quantPatterns {
            if let range = lowercased.range(of: pattern, options: .regularExpression) {
                quantization = String(lowercased[range]).uppercased()
                break
            }
        }

        return (parameters, quantization)
    }

    private func formatParameters(hiddenSize: Int) -> String {
        // Rough estimation based on hidden size
        // This is very approximate and model-dependent
        switch hiddenSize {
        case ..<2048:
            "1B"
        case 2048 ..< 4096:
            "3B"
        case 4096 ..< 6144:
            "7B"
        case 6144 ..< 8192:
            "13B"
        default:
            "70B+"
        }
    }
}

// MARK: - Data Structures

struct ScannedModel: Identifiable, Sendable {
    let id: UUID
    let name: String
    let path: URL
    let format: ModelFormat
    let sizeInBytes: Int64
    let parameters: String?
    let quantization: String?
    let modifiedDate: Date
    let status: ModelStatus

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    var displayName: String {
        var display = name
        if let params = parameters {
            display += " (\(params))"
        }
        return display
    }
}

enum ModelFormat: String, Codable, Sendable {
    case mlx = "MLX"
    case gguf = "GGUF"
    case safetensors = "SafeTensors"
    case coreML = "Core ML"
    case unknown = "Unknown"
}

enum ModelStatus: String, Codable, Sendable {
    case downloaded = "Downloaded"
    case downloading = "Downloading"
    case available = "Available"
    case error = "Error"
}

// MARK: - Errors

enum ScannerError: LocalizedError {
    case directoryNotFound(String)
    case invalidModelFormat
    case readPermissionDenied

    var errorDescription: String? {
        switch self {
        case let .directoryNotFound(path):
            "Directory not found: \(path)"
        case .invalidModelFormat:
            "Invalid model format"
        case .readPermissionDenied:
            "Permission denied to read directory"
        }
    }
}
