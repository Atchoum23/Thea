//
//  RemoteFileMessages.swift
//  Thea
//
//  File operation message types for remote server protocol
//

import Foundation

// MARK: - File Messages

public enum FileRequest: Codable, Sendable {
    case list(path: String, recursive: Bool, showHidden: Bool)
    case info(path: String)
    case read(path: String, offset: Int64, length: Int64)
    case write(path: String, data: Data, offset: Int64, append: Bool)
    case delete(path: String, recursive: Bool)
    case move(from: String, to: String)
    case copy(from: String, to: String)
    case createDirectory(path: String, intermediate: Bool)
    case download(path: String)
    case upload(path: String, data: Data, overwrite: Bool)
}

public enum FileResponse: Codable, Sendable {
    case listing([FileItem])
    case info(FileItem)
    case data(Data, isComplete: Bool)
    case success(String)
    case error(String)
    case progress(bytesTransferred: Int64, totalBytes: Int64)
}

public struct FileItem: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let permissions: String
    public let isHidden: Bool
    public let isSymlink: Bool
    public let symlinkTarget: String?

    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        permissions: String = "",
        isHidden: Bool = false,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil
    ) {
        id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.permissions = permissions
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
    }
}
