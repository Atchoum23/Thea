//
//  PhotosMonitor.swift
//  Thea
//
//  Photos and Camera activity monitoring for life tracking
//  Tracks photo taking, screenshots, and photo library changes
//

import Combine
import Foundation
import os.log
#if canImport(Photos)
    import Photos
#endif

// MARK: - Photos Monitor

/// Monitors Photos library and camera activity
/// Emits LifeEvents for new photos, screenshots, and edits
@MainActor
public class PhotosMonitor: NSObject, ObservableObject {
    public static let shared = PhotosMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "PhotosMonitor")

    @Published public private(set) var isRunning = false
    @Published public private(set) var todayPhotoCount = 0
    @Published public private(set) var todayScreenshotCount = 0
    @Published public private(set) var lastPhotoDate: Date?

    #if canImport(Photos)
        private var knownAssetIdentifiers: Set<String> = []
    #endif

    private var pollingTask: Task<Void, Never>?
    private var lastCheckedDate = Date()

    override private init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Start monitoring photos
    public func start() async {
        guard !isRunning else { return }

        #if canImport(Photos)
            // Request photos access
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized || status == .limited else {
                logger.warning("Photos access denied: \(String(describing: status))")
                return
            }

            isRunning = true
            logger.info("Photos monitor started")

            // Load initial state
            await loadInitialPhotos()

            // Register for library changes
            PHPhotoLibrary.shared().register(self)

            // Start periodic check for new photos
            startPolling()
        #else
            logger.warning("Photos framework not available")
        #endif
    }

    /// Stop monitoring
    public func stop() async {
        guard isRunning else { return }

        isRunning = false

        #if canImport(Photos)
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        #endif

        pollingTask?.cancel()
        pollingTask = nil

        logger.info("Photos monitor stopped")
    }

    // MARK: - Initial Load

    #if canImport(Photos)
        private func loadInitialPhotos() async {
            let startOfDay = Calendar.current.startOfDay(for: Date())

            // Fetch today's photos
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "creationDate >= %@", startOfDay as NSDate)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            var photoCount = 0
            var screenshotCount = 0
            var identifiers = Set<String>()

            assets.enumerateObjects { asset, _, _ in
                identifiers.insert(asset.localIdentifier)

                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    screenshotCount += 1
                } else {
                    photoCount += 1
                }
            }

            knownAssetIdentifiers = identifiers
            todayPhotoCount = photoCount
            todayScreenshotCount = screenshotCount

            if let lastAsset = assets.firstObject {
                lastPhotoDate = lastAsset.creationDate
            }

            logger.info("Loaded \(assets.count) photos for today (\(screenshotCount) screenshots)")
        }
    #endif

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await checkForNewPhotos()
                do {
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
                } catch {
                    break
                }
            }
        }
    }

    private func checkForNewPhotos() async {
        #if canImport(Photos)
            let now = Date()

            // Fetch photos since last check
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastCheckedDate as NSDate)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let newAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            // swiftlint:disable:next empty_count
            if newAssets.count > 0 { // PHFetchResult has no isEmpty
                newAssets.enumerateObjects { [weak self] asset, _, _ in
                    guard let self = self else { return }

                    // Check if we've already processed this
                    guard !self.knownAssetIdentifiers.contains(asset.localIdentifier) else { return }

                    self.knownAssetIdentifiers.insert(asset.localIdentifier)

                    Task { @MainActor in
                        await self.processNewAsset(asset)
                    }
                }
            }

            lastCheckedDate = now
        #endif
    }

    // MARK: - Asset Processing

    #if canImport(Photos)
        private func processNewAsset(_ asset: PHAsset) async {
            let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
            let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
            let isHDR = asset.mediaSubtypes.contains(.photoHDR)
            let isPanorama = asset.mediaSubtypes.contains(.photoPanorama)
            let isDepthEffect = asset.mediaSubtypes.contains(.photoDepthEffect)
            // RAW detection would require checking the resource types
            let isRAW = false

            // Update counts
            if isScreenshot {
                todayScreenshotCount += 1
            } else {
                todayPhotoCount += 1
            }
            lastPhotoDate = asset.creationDate ?? Date()

            // Determine photo type for event
            let photoType: PhotoType
            if isScreenshot {
                photoType = .screenshot
            } else if isLivePhoto {
                photoType = .livePhoto
            } else if isPanorama {
                photoType = .panorama
            } else if isDepthEffect {
                photoType = .portrait
            } else {
                photoType = .regular
            }

            // Get location if available
            var locationData: [String: String] = [:]
            if let location = asset.location {
                locationData["latitude"] = String(location.coordinate.latitude)
                locationData["longitude"] = String(location.coordinate.longitude)
            }

            // Emit event
            await emitPhotoEvent(
                photoType: photoType,
                timestamp: asset.creationDate ?? Date(),
                dimensions: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                isHDR: isHDR,
                isRAW: isRAW,
                location: locationData.isEmpty ? nil : locationData
            )
        }

        private func emitPhotoEvent(
            photoType: PhotoType,
            timestamp: Date,
            dimensions: CGSize,
            isHDR: Bool,
            isRAW: Bool,
            location: [String: String]?
        ) async {
            let eventType: LifeEventType
            let summary: String
            let significance: EventSignificance

            switch photoType {
            case .screenshot:
                eventType = .screenshotTaken
                summary = "Screenshot taken"
                significance = .trivial
            case .livePhoto:
                eventType = .photoTaken
                summary = "Live Photo captured"
                significance = .minor
            case .panorama:
                eventType = .photoTaken
                summary = "Panorama captured"
                significance = .minor
            case .portrait:
                eventType = .photoTaken
                summary = "Portrait photo captured"
                significance = .minor
            case .regular:
                eventType = .photoTaken
                summary = "Photo captured"
                significance = .minor
            case .selfie:
                eventType = .photoTaken
                summary = "Selfie captured"
                significance = .minor
            }

            var eventData: [String: String] = [
                "photoType": photoType.rawValue,
                "width": String(Int(dimensions.width)),
                "height": String(Int(dimensions.height)),
                "isHDR": String(isHDR),
                "isRAW": String(isRAW),
                "timestamp": ISO8601DateFormatter().string(from: timestamp)
            ]

            if let loc = location {
                eventData.merge(loc) { current, _ in current }
                eventData["hasLocation"] = "true"
            }

            let lifeEvent = LifeEvent(
                type: eventType,
                source: .photos,
                summary: summary,
                data: eventData,
                significance: significance
            )

            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
            logger.info("Photo event: \(photoType.rawValue)")
        }
    #endif

    // MARK: - Query Methods

    /// Get today's photo statistics
    public func getTodayStatistics() -> PhotoStatistics {
        PhotoStatistics(
            photoCount: todayPhotoCount,
            screenshotCount: todayScreenshotCount,
            lastPhotoDate: lastPhotoDate
        )
    }

    #if canImport(Photos)
        /// Get recent photos metadata
        public func getRecentPhotos(limit: Int = 10) -> [PhotoInfo] {
            var photos: [PhotoInfo] = []

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = limit

            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            assets.enumerateObjects { asset, _, _ in
                let info = PhotoInfo(
                    id: asset.localIdentifier,
                    creationDate: asset.creationDate ?? Date(),
                    width: asset.pixelWidth,
                    height: asset.pixelHeight,
                    isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                    isLivePhoto: asset.mediaSubtypes.contains(.photoLive),
                    hasLocation: asset.location != nil,
                    isFavorite: asset.isFavorite
                )
                photos.append(info)
            }

            return photos
        }
    #endif
}

// MARK: - PHPhotoLibraryChangeObserver

#if canImport(Photos)
    extension PhotosMonitor: PHPhotoLibraryChangeObserver {
        nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
            Task { @MainActor in
                await checkForNewPhotos()
            }
        }
    }
#endif

// MARK: - Supporting Types

public enum PhotoType: String, Sendable {
    case regular
    case screenshot
    case livePhoto = "live_photo"
    case panorama
    case portrait
    case selfie
}

public struct PhotoStatistics: Sendable {
    public let photoCount: Int
    public let screenshotCount: Int
    public let lastPhotoDate: Date?

    public var totalCount: Int {
        photoCount + screenshotCount
    }
}

public struct PhotoInfo: Identifiable, Sendable {
    public let id: String
    public let creationDate: Date
    public let width: Int
    public let height: Int
    public let isScreenshot: Bool
    public let isLivePhoto: Bool
    public let hasLocation: Bool
    public let isFavorite: Bool

    public var aspectRatio: Double {
        guard height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    public var megapixels: Double {
        Double(width * height) / 1_000_000
    }
}

// MARK: - LifeEventType & DataSourceType
// Note: LifeEventType cases (photo*, screenshot*) and DataSourceType.photos
// are defined in LifeMonitoringCoordinator.swift
