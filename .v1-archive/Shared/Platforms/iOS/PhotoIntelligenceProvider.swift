//
//  PhotoIntelligenceProvider.swift
//  Thea
//
//  Created by Thea
//

#if os(iOS)
    import CoreLocation
    import Foundation
    import os.log
    import Photos
    import UIKit
    import Vision

    /// Provides intelligent analysis of the photo library
    /// Uses Vision framework for image understanding
    @MainActor
    public final class PhotoIntelligenceProvider: ObservableObject {
        public static let shared = PhotoIntelligenceProvider()

        private let logger = Logger(subsystem: "app.thea.photos", category: "PhotoIntelligence")

        // Authorization
        @Published public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined

        public var isAuthorized: Bool {
            authorizationStatus == .authorized || authorizationStatus == .limited
        }

        // Analysis results
        @Published public private(set) var recentPhotos: [PhotoAnalysis] = []
        @Published public private(set) var photosByLocation: [String: [PHAsset]] = [:]
        @Published public private(set) var photosByPerson: [String: [PHAsset]] = [:]
        @Published public private(set) var todayPhotoCount: Int = 0

        // Callbacks
        public var onPhotoCaptured: ((PHAsset) -> Void)?

        private var analysisTask: Task<Void, Never>?
        private var photoLibraryObserver: PhotoLibraryObserver?

        private init() {
            updateAuthorizationStatus()
        }

        // MARK: - Monitoring

        /// Start monitoring photo library changes
        public func startMonitoring() {
            guard isAuthorized else { return }

            photoLibraryObserver = PhotoLibraryObserver { [weak self] in
                Task { @MainActor in
                    self?.handlePhotoLibraryChange()
                }
            }
            PHPhotoLibrary.shared().register(photoLibraryObserver!)
            updateTodayPhotoCount()
        }

        /// Stop monitoring
        public func stopMonitoring() {
            if let observer = photoLibraryObserver {
                PHPhotoLibrary.shared().unregisterChangeObserver(observer)
                photoLibraryObserver = nil
            }
        }

        private func handlePhotoLibraryChange() {
            updateTodayPhotoCount()
            // Optionally notify about new photos
        }

        private func updateTodayPhotoCount() {
            Task {
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let photos = await fetchPhotos(from: startOfDay, to: Date())
                todayPhotoCount = photos.count

                if let latestPhoto = photos.first {
                    onPhotoCaptured?(latestPhoto)
                }
            }
        }

        // MARK: - Authorization

        /// Request photo library access
        public func requestAuthorization() async -> PHAuthorizationStatus {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            authorizationStatus = status
            return status
        }

        private func updateAuthorizationStatus() {
            authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }

        // MARK: - Photo Queries

        /// Get recent photos
        public func fetchRecentPhotos(limit: Int = 50) async -> [PHAsset] {
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                return []
            }

            return await withCheckedContinuation { continuation in
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.fetchLimit = limit

                let results = PHAsset.fetchAssets(with: .image, options: options)
                var assets: [PHAsset] = []
                results.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }

                continuation.resume(returning: assets)
            }
        }

        /// Get photos from a specific date range
        public func fetchPhotos(from startDate: Date, to endDate: Date) async -> [PHAsset] {
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                return []
            }

            return await withCheckedContinuation { continuation in
                let options = PHFetchOptions()
                options.predicate = NSPredicate(
                    format: "creationDate >= %@ AND creationDate <= %@",
                    startDate as NSDate,
                    endDate as NSDate
                )
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                let results = PHAsset.fetchAssets(with: .image, options: options)
                var assets: [PHAsset] = []
                results.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }

                continuation.resume(returning: assets)
            }
        }

        /// Get photos near a location
        public func fetchPhotos(near location: CLLocation, radius: Double = 1000) async -> [PHAsset] {
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                return []
            }

            return await withCheckedContinuation { continuation in
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                let results = PHAsset.fetchAssets(with: .image, options: options)
                var nearbyAssets: [PHAsset] = []

                results.enumerateObjects { asset, _, _ in
                    if let assetLocation = asset.location {
                        let distance = assetLocation.distance(from: location)
                        if distance <= radius {
                            nearbyAssets.append(asset)
                        }
                    }
                }

                continuation.resume(returning: nearbyAssets)
            }
        }

        // MARK: - Vision Analysis

        /// Analyze a photo using Vision
        public func analyzePhoto(_ asset: PHAsset) async -> PhotoAnalysis? {
            guard let imageData = await loadImageData(for: asset) else {
                return nil
            }

            return await performVisionAnalysis(imageData: imageData, asset: asset)
        }

        /// Batch analyze recent photos
        public func analyzeRecentPhotos(limit: Int = 20) async {
            analysisTask?.cancel()

            analysisTask = Task {
                let assets = await fetchRecentPhotos(limit: limit)
                var analyses: [PhotoAnalysis] = []

                for asset in assets {
                    if Task.isCancelled { break }

                    if let analysis = await analyzePhoto(asset) {
                        analyses.append(analysis)
                    }
                }

                await MainActor.run {
                    self.recentPhotos = analyses
                }
            }

            await analysisTask?.value
        }

        private func loadImageData(for asset: PHAsset) async -> Data? {
            await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false

                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    continuation.resume(returning: data)
                }
            }
        }

        private func performVisionAnalysis(imageData: Data, asset: PHAsset) async -> PhotoAnalysis? {
            await withCheckedContinuation { continuation in
                guard let cgImage = UIImage(data: imageData)?.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                // Create various Vision requests
                let classificationRequest = VNClassifyImageRequest()
                let faceRequest = VNDetectFaceRectanglesRequest()
                let textRequest = VNRecognizeTextRequest()

                do {
                    try requestHandler.perform([classificationRequest, faceRequest, textRequest])

                    // Process classification results
                    var labels: [String] = []
                    var confidence: [String: Float] = [:]

                    if let classifications = classificationRequest.results {
                        for classification in classifications.prefix(5) {
                            if classification.confidence > 0.3 {
                                labels.append(classification.identifier)
                                confidence[classification.identifier] = classification.confidence
                            }
                        }
                    }

                    // Process face results
                    let faceCount = faceRequest.results?.count ?? 0

                    // Process text results
                    var detectedText: [String] = []
                    if let textObservations = textRequest.results {
                        for observation in textObservations {
                            if let text = observation.topCandidates(1).first?.string {
                                detectedText.append(text)
                            }
                        }
                    }

                    let analysis = PhotoAnalysis(
                        assetIdentifier: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        location: asset.location,
                        labels: labels,
                        confidence: confidence,
                        faceCount: faceCount,
                        detectedText: detectedText,
                        isFavorite: asset.isFavorite,
                        mediaType: asset.mediaType == .video ? .video : .photo
                    )

                    continuation.resume(returning: analysis)

                } catch {
                    self.logger.error("Vision analysis failed: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }

        // MARK: - Smart Queries

        /// Find photos with specific content
        public func findPhotos(containing _: String) async -> [PHAsset] {
            // This would use on-device ML to find photos matching the query
            // For now, return empty - would need Core ML model
            []
        }

        /// Get photo insights for a time period
        public func getInsights(for period: PhotoTimePeriod) async -> PhotoInsights {
            let endDate = Date()
            let startDate: Date = switch period {
            case .day:
                Calendar.current.startOfDay(for: endDate)
            case .week:
                Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
            case .month:
                Calendar.current.date(byAdding: .month, value: -1, to: endDate)!
            case .year:
                Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
            }

            let photos = await fetchPhotos(from: startDate, to: endDate)

            // Count photos by location
            var locationCounts: [String: Int] = [:]
            for photo in photos {
                if let location = photo.location {
                    // In a real implementation, reverse geocode the location
                    let key = "\(Int(location.coordinate.latitude)),\(Int(location.coordinate.longitude))"
                    locationCounts[key, default: 0] += 1
                }
            }

            return PhotoInsights(
                period: period,
                totalPhotos: photos.count,
                photosWithFaces: photos.count { $0.mediaSubtypes.contains(.photoHDR) }, // Placeholder
                favoritePhotos: photos.count { $0.isFavorite },
                topLocations: Array(locationCounts.sorted { $0.value > $1.value }.prefix(5).map(\.key))
            )
        }
    }

    // MARK: - Data Models

    public enum PhotoTimePeriod: String, Sendable {
        case day
        case week
        case month
        case year
    }

    public struct PhotoAnalysis: Identifiable, Sendable {
        public let id: String
        public let assetIdentifier: String
        public let creationDate: Date?
        public let location: CLLocation?
        public let labels: [String]
        public let confidence: [String: Float]
        public let faceCount: Int
        public let detectedText: [String]
        public let isFavorite: Bool
        public let mediaType: MediaType

        public enum MediaType: String, Sendable {
            case photo
            case video
        }

        init(
            assetIdentifier: String,
            creationDate: Date?,
            location: CLLocation?,
            labels: [String],
            confidence: [String: Float],
            faceCount: Int,
            detectedText: [String],
            isFavorite: Bool,
            mediaType: MediaType
        ) {
            id = assetIdentifier
            self.assetIdentifier = assetIdentifier
            self.creationDate = creationDate
            self.location = location
            self.labels = labels
            self.confidence = confidence
            self.faceCount = faceCount
            self.detectedText = detectedText
            self.isFavorite = isFavorite
            self.mediaType = mediaType
        }
    }

    public struct PhotoInsights: Sendable {
        public let period: PhotoTimePeriod
        public let totalPhotos: Int
        public let photosWithFaces: Int
        public let favoritePhotos: Int
        public let topLocations: [String]
    }

    // MARK: - Photo Library Observer

    private class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
        private let onChange: () -> Void

        init(onChange: @escaping () -> Void) {
            self.onChange = onChange
            super.init()
        }

        func photoLibraryDidChange(_: PHChange) {
            onChange()
        }
    }
#endif
