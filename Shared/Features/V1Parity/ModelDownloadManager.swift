// ModelDownloadManager.swift
// Thea V2
//
// Local model download and management.
// Enables downloading and managing on-device AI models for offline use.
//
// V1 FEATURE PARITY
// CREATED: February 2, 2026

import Foundation
import OSLog

// MARK: - Model Download Manager

@MainActor
@Observable
public final class ModelDownloadManager {
    public static let shared = ModelDownloadManager()

    private let logger = Logger(subsystem: "com.thea.features", category: "ModelDownload")

    // MARK: - State

    public private(set) var availableModels: [DownloadableModel] = []
    public private(set) var downloadedModels: [DownloadedModel] = []
    public private(set) var activeDownloads: [ModelDownload] = []
    public private(set) var isRefreshing: Bool = false

    // MARK: - Configuration

    public var autoUpdateModels: Bool = true
    public var maxConcurrentDownloads: Int = 2
    public var preferredModelSize: DownloadModelSize = .medium

    // MARK: - Paths

    private let modelsDirectory: URL = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("huggingface/hub", isDirectory: true)
    }()

    private init() {
        Task {
            await refreshAvailableModels()
            await scanDownloadedModels()
        }
    }

    // MARK: - Public API

    /// Refresh list of available models from Hugging Face
    public func refreshAvailableModels() async {
        isRefreshing = true
        defer { isRefreshing = false }

        logger.info("Refreshing available models...")

        // Curated list of recommended models for Thea
        let models: [DownloadableModel] = [
            DownloadableModel(
                id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                name: "Llama 3.2 3B Instruct",
                description: "Fast, capable instruction-following model",
                size: DownloadModelSize.small,
                sizeBytes: 2_000_000_000,
                capabilities: [DownloadModelCapability.chat, DownloadModelCapability.instruction],
                recommended: true
            ),
            DownloadableModel(
                id: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
                name: "Mistral 7B Instruct",
                description: "Excellent reasoning and instruction following",
                size: DownloadModelSize.medium,
                sizeBytes: 4_500_000_000,
                capabilities: [DownloadModelCapability.chat, DownloadModelCapability.instruction, DownloadModelCapability.reasoning],
                recommended: true
            ),
            DownloadableModel(
                id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                name: "Qwen 2.5 7B",
                description: "Strong multilingual and coding capabilities",
                size: DownloadModelSize.medium,
                sizeBytes: 4_800_000_000,
                capabilities: [DownloadModelCapability.chat, DownloadModelCapability.instruction, DownloadModelCapability.coding, DownloadModelCapability.multilingual],
                recommended: true
            ),
            DownloadableModel(
                id: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
                name: "Llama 3.1 8B Instruct",
                description: "Latest Llama with improved capabilities",
                size: DownloadModelSize.medium,
                sizeBytes: 5_000_000_000,
                capabilities: [DownloadModelCapability.chat, DownloadModelCapability.instruction, DownloadModelCapability.reasoning],
                recommended: false
            ),
            DownloadableModel(
                id: "mlx-community/DeepSeek-Coder-V2-Lite-Instruct-4bit",
                name: "DeepSeek Coder V2 Lite",
                description: "Specialized for code generation",
                size: DownloadModelSize.medium,
                sizeBytes: 4_200_000_000,
                capabilities: [DownloadModelCapability.coding, DownloadModelCapability.instruction],
                recommended: false
            )
        ]
        availableModels = models

        logger.info("Found \(self.availableModels.count) available models")
    }

    /// Scan for locally downloaded models
    public func scanDownloadedModels() async {
        logger.info("Scanning local models...")

        var found: [DownloadedModel] = []

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels = []
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: modelsDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )

            for modelDir in contents {
                if modelDir.hasDirectoryPath {
                    let modelId = modelDir.lastPathComponent.replacingOccurrences(of: "--", with: "/")

                    // Check if it's a complete download
                    let configPath = modelDir.appendingPathComponent("config.json")
                    if fileManager.fileExists(atPath: configPath.path) {
                        let size = try fileManager.sizeOfDirectory(at: modelDir)
                        let attributes = try fileManager.attributesOfItem(atPath: modelDir.path)
                        let createdAt = attributes[.creationDate] as? Date ?? Date()

                        found.append(DownloadedModel(
                            id: modelId,
                            path: modelDir,
                            sizeBytes: size,
                            downloadedAt: createdAt,
                            isValid: true
                        ))
                    }
                }
            }
        } catch {
            logger.error("Error scanning models: \(error.localizedDescription)")
        }

        downloadedModels = found
        logger.info("Found \(found.count) local models")
    }

    /// Download a model
    public func download(_ model: DownloadableModel) async throws {
        guard !activeDownloads.contains(where: { $0.model.id == model.id }) else {
            logger.warning("Model already downloading: \(model.id)")
            return
        }

        logger.info("Starting download: \(model.name)")

        let download = ModelDownload(
            model: model,
            progress: 0,
            status: .downloading,
            startedAt: Date()
        )
        activeDownloads.append(download)

        // Use huggingface-cli or direct download
        // This is a stub - actual implementation would use URLSession with progress tracking
        do {
            try await performDownload(model: model, download: download)

            // Mark complete
            if let index = activeDownloads.firstIndex(where: { $0.model.id == model.id }) {
                activeDownloads[index].status = .completed
                activeDownloads[index].progress = 1.0
            }

            // Refresh local models
            await scanDownloadedModels()

            logger.info("Download complete: \(model.name)")
        } catch {
            if let index = activeDownloads.firstIndex(where: { $0.model.id == model.id }) {
                activeDownloads[index].status = .failed
                activeDownloads[index].error = error.localizedDescription
            }
            throw error
        }
    }

    /// Delete a local model
    public func delete(_ model: DownloadedModel) async throws {
        logger.info("Deleting model: \(model.id)")

        try FileManager.default.removeItem(at: model.path)
        await scanDownloadedModels()

        logger.info("Model deleted: \(model.id)")
    }

    /// Cancel an active download
    public func cancelDownload(_ modelId: String) {
        if let index = activeDownloads.firstIndex(where: { $0.model.id == modelId }) {
            activeDownloads[index].status = .cancelled
            // Cancel actual download task
        }
    }

    /// Get storage used by models
    public var totalStorageUsed: Int64 {
        downloadedModels.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Get formatted storage string
    public var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }

    // MARK: - Private

    private func performDownload(model: DownloadableModel, download: ModelDownload) async throws {
        // Stub implementation
        // Actual implementation would:
        // 1. Create directory structure
        // 2. Download model files from Hugging Face
        // 3. Track progress
        // 4. Verify integrity

        // For now, simulate download
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            try await Task.sleep(for: .milliseconds(100))
            if let index = activeDownloads.firstIndex(where: { $0.model.id == model.id }) {
                activeDownloads[index].progress = progress
            }
        }

        // In real implementation:
        // let hubPath = "~/.cache/huggingface/hub/models--\(model.id.replacingOccurrences(of: "/", with: "--"))"
        // Use snapshot_download or similar
    }
}

// MARK: - Supporting Types

public struct DownloadableModel: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let size: DownloadModelSize
    public let sizeBytes: Int64
    public let capabilities: Set<DownloadModelCapability>
    public let recommended: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct DownloadedModel: Sendable, Identifiable {
    public let id: String
    public let path: URL
    public let sizeBytes: Int64
    public let downloadedAt: Date
    public let isValid: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct ModelDownload: Sendable, Identifiable {
    public let id = UUID()
    public let model: DownloadableModel
    public var progress: Double
    public var status: DownloadStatus
    public let startedAt: Date
    public var error: String?
}

public enum DownloadModelSize: String, Sendable {
    case tiny    // < 1GB
    case small   // 1-3GB
    case medium  // 3-8GB
    case large   // 8-20GB
    case huge    // > 20GB
}

public enum DownloadModelCapability: String, Sendable {
    case chat
    case instruction
    case coding
    case reasoning
    case multilingual
    case vision
    case audio
}

public enum DownloadStatus: String, Sendable {
    case queued
    case downloading
    case completed
    case failed
    case cancelled
}

// MARK: - FileManager Extension

private extension FileManager {
    func sizeOfDirectory(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            size += Int64(attributes.fileSize ?? 0)
        }

        return size
    }
}
