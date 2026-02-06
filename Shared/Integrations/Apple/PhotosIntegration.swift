// PhotosIntegration.swift
// Thea V2
//
// Deep integration with Apple Photos framework
// Provides photo library access, search, and album management

import Foundation
import OSLog

#if canImport(Photos)
import Photos
import PhotosUI
#endif

#if canImport(CoreImage)
import CoreImage
#endif

// MARK: - Photo Models

/// Represents a photo or video asset in the system
public struct TheaPhotoAsset: Identifiable, Sendable {
    public let id: String
    public let mediaType: PhotoMediaType
    public let mediaSubtypes: Set<PhotoMediaSubtype>
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let creationDate: Date?
    public let modificationDate: Date?
    public let location: PhotoLocation?
    public let duration: TimeInterval  // For videos
    public let isFavorite: Bool
    public let isHidden: Bool
    public let localIdentifier: String
    public let burstIdentifier: String?

    public var isVideo: Bool {
        mediaType == .video
    }

    public var isPhoto: Bool {
        mediaType == .image
    }

    public var aspectRatio: Double {
        guard pixelHeight > 0 else { return 1.0 }
        return Double(pixelWidth) / Double(pixelHeight)
    }

    public init(
        id: String = UUID().uuidString,
        mediaType: PhotoMediaType = .image,
        mediaSubtypes: Set<PhotoMediaSubtype> = [],
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        location: PhotoLocation? = nil,
        duration: TimeInterval = 0,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        localIdentifier: String = "",
        burstIdentifier: String? = nil
    ) {
        self.id = id
        self.mediaType = mediaType
        self.mediaSubtypes = mediaSubtypes
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.location = location
        self.duration = duration
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.localIdentifier = localIdentifier
        self.burstIdentifier = burstIdentifier
    }
}

/// Media type for photos
public enum PhotoMediaType: String, Sendable, Codable {
    case image
    case video
    case audio
    case unknown
}

/// Media subtypes for photos
public enum PhotoMediaSubtype: String, Sendable, Codable, CaseIterable {
    case panorama
    case hdr
    case screenshot
    case live
    case depthEffect
    case burst
    case highFrameRate
    case timelapse
    case cinematicVideo
    case spatialMedia
}

/// Location for photos
public struct PhotoLocation: Sendable, Codable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let placeName: String?
    public let city: String?
    public let country: String?

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        placeName: String? = nil,
        city: String? = nil,
        country: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.placeName = placeName
        self.city = city
        self.country = country
    }
}

/// Photo album
public struct TheaPhotoAlbum: Identifiable, Sendable {
    public let id: String
    public var title: String
    public let assetCount: Int
    public let albumType: PhotoAlbumType
    public let startDate: Date?
    public let endDate: Date?
    public let localIdentifier: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        assetCount: Int = 0,
        albumType: PhotoAlbumType = .album,
        startDate: Date? = nil,
        endDate: Date? = nil,
        localIdentifier: String = ""
    ) {
        self.id = id
        self.title = title
        self.assetCount = assetCount
        self.albumType = albumType
        self.startDate = startDate
        self.endDate = endDate
        self.localIdentifier = localIdentifier
    }
}

/// Album types
public enum PhotoAlbumType: String, Sendable, Codable {
    case album
    case smartAlbum
    case folder
    case moment
    case memory
}

// MARK: - Search Criteria

/// Search criteria for photos
public struct PhotoSearchCriteria: Sendable {
    public var mediaTypes: Set<PhotoMediaType>?
    public var mediaSubtypes: Set<PhotoMediaSubtype>?
    public var startDate: Date?
    public var endDate: Date?
    public var isFavorite: Bool?
    public var isHidden: Bool?
    public var albumId: String?
    public var locationRadius: (latitude: Double, longitude: Double, radiusMeters: Double)?
    public var sortOrder: PhotoSortOrder
    public var limit: Int?

    public init(
        mediaTypes: Set<PhotoMediaType>? = nil,
        mediaSubtypes: Set<PhotoMediaSubtype>? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isFavorite: Bool? = nil,
        isHidden: Bool? = nil,
        albumId: String? = nil,
        locationRadius: (latitude: Double, longitude: Double, radiusMeters: Double)? = nil,
        sortOrder: PhotoSortOrder = .creationDateDescending,
        limit: Int? = nil
    ) {
        self.mediaTypes = mediaTypes
        self.mediaSubtypes = mediaSubtypes
        self.startDate = startDate
        self.endDate = endDate
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.albumId = albumId
        self.locationRadius = locationRadius
        self.sortOrder = sortOrder
        self.limit = limit
    }

    public static var recentPhotos: PhotoSearchCriteria {
        PhotoSearchCriteria(
            mediaTypes: [.image],
            sortOrder: .creationDateDescending,
            limit: 100
        )
    }

    public static var favorites: PhotoSearchCriteria {
        PhotoSearchCriteria(isFavorite: true)
    }

    public static var videos: PhotoSearchCriteria {
        PhotoSearchCriteria(mediaTypes: [.video])
    }

    public static var screenshots: PhotoSearchCriteria {
        PhotoSearchCriteria(mediaSubtypes: [.screenshot])
    }

    public static func photos(from startDate: Date, to endDate: Date) -> PhotoSearchCriteria {
        PhotoSearchCriteria(startDate: startDate, endDate: endDate)
    }
}

/// Sort order for photos
public enum PhotoSortOrder: String, Sendable {
    case creationDateAscending
    case creationDateDescending
    case modificationDateAscending
    case modificationDateDescending
}

// MARK: - Photos Integration Actor

/// Actor for managing Photos operations
/// Thread-safe access to Photos framework
@available(macOS 10.15, iOS 14.0, *)
public actor PhotosIntegration {
    public static let shared = PhotosIntegration()

    private let logger = Logger(subsystem: "com.thea.integrations", category: "Photos")

    #if canImport(Photos)
    private let imageManager = PHCachingImageManager()
    #endif

    private init() {}

    // MARK: - Authorization

    /// Check current authorization status
    public var authorizationStatus: PhotoAuthorizationStatus {
        #if canImport(Photos)
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        case .limited:
            return .limited
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    /// Request access to photos
    public func requestAccess() async -> Bool {
        #if canImport(Photos)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let granted = status == .authorized || status == .limited
        logger.info("Photos access \(granted ? "granted" : "denied") (status: \(String(describing: status)))")
        return granted
        #else
        return false
        #endif
    }

    // MARK: - Album Operations

    /// Fetch all albums
    public func fetchAlbums() async throws -> [TheaPhotoAlbum] {
        #if canImport(Photos)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosError.notAuthorized
        }

        var albums: [TheaPhotoAlbum] = []

        // User albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        albums.append(contentsOf: enumerateAlbums(userAlbums, type: .album))

        // Smart albums
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        albums.append(contentsOf: enumerateAlbums(smartAlbums, type: .smartAlbum))

        logger.info("Fetched \(albums.count) albums")
        return albums
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Create a new album
    public func createAlbum(title: String) async throws -> TheaPhotoAlbum {
        #if canImport(Photos)
        guard authorizationStatus == .authorized else {
            throw PhotosError.notAuthorized
        }

        var placeholder: PHObjectPlaceholder?

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            placeholder = request.placeholderForCreatedAssetCollection
        }

        guard let localId = placeholder?.localIdentifier,
              let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [localId],
                options: nil
              ).firstObject else {
            throw PhotosError.createFailed("Failed to create album")
        }

        logger.info("Created album: \(title)")

        return TheaPhotoAlbum(
            id: collection.localIdentifier,
            title: collection.localizedTitle ?? title,
            assetCount: 0,
            albumType: .album,
            localIdentifier: collection.localIdentifier
        )
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Delete an album
    public func deleteAlbum(identifier: String) async throws {
        #if canImport(Photos)
        guard authorizationStatus == .authorized else {
            throw PhotosError.notAuthorized
        }

        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [identifier],
            options: nil
        )

        guard let collection = collections.firstObject else {
            throw PhotosError.albumNotFound
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSFastEnumeration)
        }

        logger.info("Deleted album: \(identifier)")
        #else
        throw PhotosError.unavailable
        #endif
    }

    // MARK: - Photo Fetch Operations

    /// Fetch all photos
    public func fetchAllPhotos(limit: Int? = nil) async throws -> [TheaPhotoAsset] {
        #if canImport(Photos)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosError.notAuthorized
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let limit = limit {
            options.fetchLimit = limit
        }

        let results = PHAsset.fetchAssets(with: options)
        return enumerateAssets(results)
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Fetch photos by criteria
    public func fetchPhotos(criteria: PhotoSearchCriteria) async throws -> [TheaPhotoAsset] {
        #if canImport(Photos)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosError.notAuthorized
        }

        let options = PHFetchOptions()

        // Build predicates
        var predicates: [NSPredicate] = []

        // Media type
        if let mediaTypes = criteria.mediaTypes {
            let phTypes = mediaTypes.compactMap { type -> PHAssetMediaType? in
                switch type {
                case .image: return .image
                case .video: return .video
                case .audio: return .audio
                case .unknown: return nil
                }
            }
            if !phTypes.isEmpty {
                predicates.append(NSPredicate(format: "mediaType IN %@", phTypes.map { $0.rawValue }))
            }
        }

        // Date range
        if let startDate = criteria.startDate {
            predicates.append(NSPredicate(format: "creationDate >= %@", startDate as CVarArg))
        }
        if let endDate = criteria.endDate {
            predicates.append(NSPredicate(format: "creationDate <= %@", endDate as CVarArg))
        }

        // Favorite
        if let isFavorite = criteria.isFavorite {
            predicates.append(NSPredicate(format: "isFavorite == %@", NSNumber(value: isFavorite)))
        }

        // Hidden
        if let isHidden = criteria.isHidden {
            predicates.append(NSPredicate(format: "isHidden == %@", NSNumber(value: isHidden)))
        }

        // Combine predicates
        if !predicates.isEmpty {
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // Sort order
        switch criteria.sortOrder {
        case .creationDateAscending:
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        case .creationDateDescending:
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .modificationDateAscending:
            options.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: true)]
        case .modificationDateDescending:
            options.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        }

        // Limit
        if let limit = criteria.limit {
            options.fetchLimit = limit
        }

        // Fetch from album or all photos
        let results: PHFetchResult<PHAsset>
        if let albumId = criteria.albumId {
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumId],
                options: nil
            )
            if let collection = collections.firstObject {
                results = PHAsset.fetchAssets(in: collection, options: options)
            } else {
                throw PhotosError.albumNotFound
            }
        } else {
            results = PHAsset.fetchAssets(with: options)
        }

        var assets = enumerateAssets(results)

        // Filter by media subtypes (post-fetch since not supported in predicate)
        if let subtypes = criteria.mediaSubtypes, !subtypes.isEmpty {
            assets = assets.filter { asset in
                !asset.mediaSubtypes.isDisjoint(with: subtypes)
            }
        }

        logger.info("Fetched \(assets.count) photos matching criteria")
        return assets
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Fetch a single photo by identifier
    public func fetchPhoto(identifier: String) async throws -> TheaPhotoAsset? {
        #if canImport(Photos)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosError.notAuthorized
        }

        let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return results.firstObject.map { convertToTheaAsset($0) }
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Fetch photos in album
    public func fetchPhotos(inAlbum albumId: String, limit: Int? = nil) async throws -> [TheaPhotoAsset] {
        let criteria = PhotoSearchCriteria(
            albumId: albumId,
            limit: limit
        )
        return try await fetchPhotos(criteria: criteria)
    }

    // MARK: - Photo Operations

    /// Add photo to album
    public func addPhoto(identifier: String, toAlbum albumId: String) async throws {
        #if canImport(Photos)
        guard authorizationStatus == .authorized else {
            throw PhotosError.notAuthorized
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotosError.assetNotFound
        }

        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId],
            options: nil
        )
        guard let collection = collections.firstObject else {
            throw PhotosError.albumNotFound
        }

        try await PHPhotoLibrary.shared().performChanges {
            guard let request = PHAssetCollectionChangeRequest(for: collection) else {
                return
            }
            request.addAssets([asset] as NSFastEnumeration)
        }

        logger.info("Added photo \(identifier) to album \(albumId)")
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Remove photo from album
    public func removePhoto(identifier: String, fromAlbum albumId: String) async throws {
        #if canImport(Photos)
        guard authorizationStatus == .authorized else {
            throw PhotosError.notAuthorized
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotosError.assetNotFound
        }

        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId],
            options: nil
        )
        guard let collection = collections.firstObject else {
            throw PhotosError.albumNotFound
        }

        try await PHPhotoLibrary.shared().performChanges {
            guard let request = PHAssetCollectionChangeRequest(for: collection) else {
                return
            }
            request.removeAssets([asset] as NSFastEnumeration)
        }

        logger.info("Removed photo \(identifier) from album \(albumId)")
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Toggle favorite status
    public func setFavorite(identifier: String, isFavorite: Bool) async throws {
        #if canImport(Photos)
        guard authorizationStatus == .authorized else {
            throw PhotosError.notAuthorized
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotosError.assetNotFound
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = isFavorite
        }

        logger.info("Set favorite=\(isFavorite) for photo \(identifier)")
        #else
        throw PhotosError.unavailable
        #endif
    }

    /// Delete photos
    public func deletePhotos(identifiers: [String]) async throws {
        #if canImport(Photos)
        guard authorizationStatus == .authorized else {
            throw PhotosError.notAuthorized
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }

        logger.info("Deleted \(identifiers.count) photos")
        #else
        throw PhotosError.unavailable
        #endif
    }

    // MARK: - Image Data

    #if canImport(Photos) && canImport(AppKit)
    /// Get image data for a photo
    public func getImageData(
        identifier: String,
        targetSize: CGSize? = nil,
        contentMode: PHImageContentMode = .aspectFit
    ) async throws -> Data? {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosError.notAuthorized
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotosError.assetNotFound
        }

        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isSynchronous = false
        requestOptions.isNetworkAccessAllowed = true

        let size = targetSize ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight)

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: contentMode,
                options: requestOptions
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    #if os(macOS)
                    let bitmapRep = NSBitmapImageRep(data: image.tiffRepresentation!)
                    let data = bitmapRep?.representation(using: .jpeg, properties: [:])
                    #else
                    let data = image.jpegData(compressionQuality: 0.9)
                    #endif
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif

    // MARK: - Statistics

    /// Get library statistics
    public func getLibraryStatistics() async throws -> PhotoLibraryStatistics {
        #if canImport(Photos)
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosError.notAuthorized
        }

        let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
        let allVideos = PHAsset.fetchAssets(with: .video, options: nil)

        let favoritesOptions = PHFetchOptions()
        favoritesOptions.predicate = NSPredicate(format: "isFavorite == YES")
        let favorites = PHAsset.fetchAssets(with: favoritesOptions)

        let screenshotsOptions = PHFetchOptions()
        screenshotsOptions.predicate = NSPredicate(
            format: "mediaSubtype == %d",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        let screenshots = PHAsset.fetchAssets(with: screenshotsOptions)

        return PhotoLibraryStatistics(
            totalPhotos: allPhotos.count,
            totalVideos: allVideos.count,
            favorites: favorites.count,
            screenshots: screenshots.count
        )
        #else
        throw PhotosError.unavailable
        #endif
    }

    // MARK: - Helper Methods

    #if canImport(Photos)
    nonisolated private func enumerateAlbums(
        _ results: PHFetchResult<PHAssetCollection>,
        type: PhotoAlbumType
    ) -> [TheaPhotoAlbum] {
        var albums: [TheaPhotoAlbum] = []
        for i in 0..<results.count {
            let collection = results.object(at: i)
            let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
            albums.append(TheaPhotoAlbum(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "Untitled",
                assetCount: assetCount,
                albumType: type,
                startDate: collection.startDate,
                endDate: collection.endDate,
                localIdentifier: collection.localIdentifier
            ))
        }
        return albums
    }

    nonisolated private func enumerateAssets(_ results: PHFetchResult<PHAsset>) -> [TheaPhotoAsset] {
        var assets: [TheaPhotoAsset] = []
        for i in 0..<results.count {
            let asset = results.object(at: i)
            assets.append(convertToTheaAsset(asset))
        }
        return assets
    }

    nonisolated private func convertToTheaAsset(_ asset: PHAsset) -> TheaPhotoAsset {
        let mediaType: PhotoMediaType
        switch asset.mediaType {
        case .image:
            mediaType = .image
        case .video:
            mediaType = .video
        case .audio:
            mediaType = .audio
        default:
            mediaType = .unknown
        }

        var subtypes: Set<PhotoMediaSubtype> = []
        if asset.mediaSubtypes.contains(.photoPanorama) { subtypes.insert(.panorama) }
        if asset.mediaSubtypes.contains(.photoHDR) { subtypes.insert(.hdr) }
        if asset.mediaSubtypes.contains(.photoScreenshot) { subtypes.insert(.screenshot) }
        if asset.mediaSubtypes.contains(.photoLive) { subtypes.insert(.live) }
        if asset.mediaSubtypes.contains(.photoDepthEffect) { subtypes.insert(.depthEffect) }
        if asset.burstIdentifier != nil { subtypes.insert(.burst) }
        if asset.mediaSubtypes.contains(.videoHighFrameRate) { subtypes.insert(.highFrameRate) }
        if asset.mediaSubtypes.contains(.videoTimelapse) { subtypes.insert(.timelapse) }
        if asset.mediaSubtypes.contains(.videoCinematic) { subtypes.insert(.cinematicVideo) }
        if #available(macOS 14.0, iOS 17.0, *) {
            if asset.mediaSubtypes.contains(.spatialMedia) { subtypes.insert(.spatialMedia) }
        }

        var location: PhotoLocation?
        if let clLocation = asset.location {
            location = PhotoLocation(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude,
                altitude: clLocation.altitude
            )
        }

        return TheaPhotoAsset(
            id: asset.localIdentifier,
            mediaType: mediaType,
            mediaSubtypes: subtypes,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            location: location,
            duration: asset.duration,
            isFavorite: asset.isFavorite,
            isHidden: asset.isHidden,
            localIdentifier: asset.localIdentifier,
            burstIdentifier: asset.burstIdentifier
        )
    }
    #endif
}

// MARK: - Supporting Types

/// Authorization status for photos
public enum PhotoAuthorizationStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case limited
    case unavailable
}

/// Library statistics
public struct PhotoLibraryStatistics: Sendable {
    public let totalPhotos: Int
    public let totalVideos: Int
    public let favorites: Int
    public let screenshots: Int

    public var totalAssets: Int {
        totalPhotos + totalVideos
    }
}

/// Errors for photo operations
public enum PhotosError: LocalizedError {
    case notAuthorized
    case unavailable
    case assetNotFound
    case albumNotFound
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Photos access not authorized"
        case .unavailable:
            "Photos framework not available on this platform"
        case .assetNotFound:
            "Photo asset not found"
        case .albumNotFound:
            "Photo album not found"
        case .createFailed(let reason):
            "Failed to create: \(reason)"
        case .updateFailed(let reason):
            "Failed to update: \(reason)"
        case .deleteFailed(let reason):
            "Failed to delete: \(reason)"
        }
    }
}
