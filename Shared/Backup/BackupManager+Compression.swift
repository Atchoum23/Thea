// BackupManager+Compression.swift
// Compression and archive methods for BackupManager

import Compression
import Foundation

extension BackupManager {
    // MARK: - Compression

    func compressDirectory(_ source: URL, to destination: URL) async throws {
        let archiveData = try createArchive(from: source)
        let compressedData = try compress(archiveData)
        try compressedData.write(to: destination)
    }

    func decompressArchive(_ source: URL, to destination: URL) async throws {
        let compressedData = try Data(contentsOf: source)
        let archiveData = try decompress(compressedData)
        try extractArchive(archiveData, to: destination)
    }

    private func createArchive(from directory: URL) throws -> Data {
        // Simple archive format: JSON manifest + file contents
        var archive = ArchiveContainer(files: [])

        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            let isDirectory: Bool
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                isDirectory = resourceValues.isDirectory ?? false
            } catch {
                logger.debug("Could not read directory attribute for \(relativePath): \(error.localizedDescription)")
                isDirectory = false
            }

            if !isDirectory {
                let data = try Data(contentsOf: fileURL)
                archive.files.append(ArchivedFile(path: relativePath, data: data))
            }
        }

        return try JSONEncoder().encode(archive)
    }

    private func extractArchive(_ data: Data, to directory: URL) throws {
        let archive = try JSONDecoder().decode(ArchiveContainer.self, from: data)

        for file in archive.files {
            let filePath = directory.appendingPathComponent(file.path)
            let parentDir = filePath.deletingLastPathComponent()

            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try file.data.write(to: filePath)
        }
    }

    private func compress(_ data: Data) throws -> Data {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourcePtr in
            compression_encode_buffer(
                destinationBuffer,
                data.count,
                sourcePtr.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                COMPRESSION_LZMA
            )
        }

        guard compressedSize > 0 else {
            throw BackupError.compressionFailed
        }

        return Data(bytes: destinationBuffer, count: compressedSize)
    }

    private func decompress(_ data: Data) throws -> Data {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count * 10) // Estimate
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourcePtr in
            compression_decode_buffer(
                destinationBuffer,
                data.count * 10,
                sourcePtr.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                COMPRESSION_LZMA
            )
        }

        guard decompressedSize > 0 else {
            throw BackupError.decompressionFailed
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
