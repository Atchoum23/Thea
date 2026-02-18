// IntelligentPrefetcher.swift
// Thea V2
//
// Intelligent Prefetcher - Predicts and preloads resources before needed
// Implements speculative prefetching for instant response times

import Foundation
import OSLog

// MARK: - Intelligent Prefetcher

/// Predicts what resources will be needed and preloads them
@MainActor
public final class IntelligentPrefetcher: ObservableObject {

    public static let shared = IntelligentPrefetcher()

    private let logger = Logger(subsystem: "app.thea.intelligence", category: "Prefetcher")

    // MARK: - State

    @Published public private(set) var prefetchedResources: [PrefetchedResource] = []
    @Published public private(set) var prefetchQueue: [PrefetchRequest] = []
    @Published public private(set) var stats = PrefetchStats()

    private var resourceCache: [String: CachedResource] = [:]
    private let maxCacheSize = 50
    private let cacheExpirationTime: TimeInterval = 600

    // MARK: - Configuration

    public var maxConcurrentPrefetches: Int = 3
    public var minConfidenceThreshold: Float = 0.4

    // MARK: - Prefetching

    private var prefetchTask: Task<Void, Never>?
    private var activePrefetches: Int = 0

    public func startPrefetching() {
        prefetchTask = Task {
            while !Task.isCancelled {
                await processPrefetchQueue()
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    break
                }
            }
        }
        logger.info("Intelligent prefetching started")
    }

    public func stopPrefetching() {
        prefetchTask?.cancel()
    }

    public func requestPrefetch(for predictions: [PrefetchPredictedAction]) {
        for prediction in predictions where prediction.confidence >= minConfidenceThreshold {
            let resources = determineResourcesNeeded(for: prediction)
            for resource in resources where !isResourceAvailable(resource.key) && !prefetchQueue.contains(where: { $0.key == resource.key }) {
                prefetchQueue.append(PrefetchRequest(
                    id: UUID(), key: resource.key, type: resource.type,
                    priority: resource.priority * prediction.confidence,
                    createdAt: Date(), deadline: Date().addingTimeInterval(30)
                ))
            }
        }
        prefetchQueue.sort { $0.priority > $1.priority }
    }

    private func determineResourcesNeeded(for prediction: PrefetchPredictedAction) -> [ResourceSpec] {
        switch prediction.actionType {
        case .codeCompletion: return [ResourceSpec(key: "model:code-completion", type: PrefetchResourceType.model, priority: 0.9)]
        case .search: return [ResourceSpec(key: "api:search-ready", type: PrefetchResourceType.apiConnection, priority: 0.8)]
        case .aiChat: return [ResourceSpec(key: "api:anthropic-ready", type: PrefetchResourceType.apiConnection, priority: 0.9)]
        case .fileOpen(let path): return [ResourceSpec(key: "file:\(path)", type: PrefetchResourceType.file, priority: 0.95)]
        case .webSearch: return [ResourceSpec(key: "api:web-search-ready", type: PrefetchResourceType.apiConnection, priority: 0.85)]
        case .localModel: return [ResourceSpec(key: "model:local-llm", type: PrefetchResourceType.model, priority: 0.95)]
        case .dataAnalysis: return [ResourceSpec(key: "model:data-analysis", type: PrefetchResourceType.model, priority: 0.8)]
        }
    }

    private func processPrefetchQueue() async {
        guard !prefetchQueue.isEmpty && activePrefetches < maxConcurrentPrefetches else { return }

        let request = prefetchQueue.removeFirst()
        guard Date() <= request.deadline else { stats.expiredRequests += 1; return }

        activePrefetches += 1
        defer { activePrefetches -= 1 }

        let resource = PrefetchedResource(key: request.key, type: request.type, loadedAt: Date())
        cacheResource(resource)
        stats.successfulPrefetches += 1
        logger.debug("Prefetched: \(request.key)")
    }

    private func cacheResource(_ resource: PrefetchedResource) {
        if resourceCache.count >= maxCacheSize { evictLeastRecentlyUsed() }
        resourceCache[resource.key] = CachedResource(resource: resource, lastAccessedAt: Date())
        prefetchedResources.append(resource)
        if prefetchedResources.count > maxCacheSize { prefetchedResources.removeFirst() }
    }

    private func evictLeastRecentlyUsed() {
        if let oldest = resourceCache.min(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt }) {
            resourceCache.removeValue(forKey: oldest.key)
        }
    }

    public func isResourceAvailable(_ key: String) -> Bool {
        guard let cached = resourceCache[key] else { return false }
        if Date().timeIntervalSince(cached.resource.loadedAt) > cacheExpirationTime {
            resourceCache.removeValue(forKey: key)
            return false
        }
        return true
    }

    public func getResource(_ key: String) -> PrefetchedResource? {
        guard var cached = resourceCache[key] else { stats.cacheMisses += 1; return nil }
        if Date().timeIntervalSince(cached.resource.loadedAt) > cacheExpirationTime {
            resourceCache.removeValue(forKey: key)
            stats.cacheMisses += 1
            return nil
        }
        cached.lastAccessedAt = Date()
        resourceCache[key] = cached
        stats.cacheHits += 1
        return cached.resource
    }
}

// MARK: - Supporting Types

public struct PrefetchPredictedAction: Sendable {
    public let actionType: ActionType
    public let confidence: Float

    public enum ActionType: Sendable {
        case codeCompletion, search, fileOpen(path: String), aiChat, webSearch, localModel, dataAnalysis
    }

    public init(actionType: ActionType, confidence: Float) {
        self.actionType = actionType
        self.confidence = confidence
    }
}

public struct ResourceSpec: Sendable {
    public let key: String
    public let type: PrefetchResourceType
    public let priority: Float
}

public enum PrefetchResourceType: String, Sendable { case model, file, context, apiConnection, index }

public struct PrefetchRequest: Identifiable, Sendable {
    public let id: UUID
    public let key: String
    public let type: PrefetchResourceType
    public let priority: Float
    public let createdAt: Date
    public let deadline: Date
}

public struct PrefetchedResource: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let type: PrefetchResourceType
    public let loadedAt: Date
}

public struct CachedResource: Sendable {
    public let resource: PrefetchedResource
    public var lastAccessedAt: Date
}

public struct PrefetchStats: Sendable {
    public var successfulPrefetches: Int = 0
    public var failedPrefetches: Int = 0
    public var expiredRequests: Int = 0
    public var cacheHits: Int = 0
    public var cacheMisses: Int = 0
}
