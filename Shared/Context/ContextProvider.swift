import Foundation

// MARK: - Context Provider Protocol

/// Protocol for all context providers to implement
public protocol ContextProvider: Actor {
    /// Unique identifier for this provider
    var providerId: String { get }

    /// Human-readable name
    var displayName: String { get }

    /// Whether this provider is currently active and collecting data
    var isActive: Bool { get }

    /// Whether this provider requires user permission
    var requiresPermission: Bool { get }

    /// Whether permission has been granted
    var hasPermission: Bool { get async }

    /// Start collecting context updates
    func start() async throws

    /// Stop collecting context updates
    func stop() async

    /// Request permission from user if needed
    func requestPermission() async throws -> Bool

    /// Get the current context from this provider
    func getCurrentContext() async -> ContextUpdate?

    /// Stream of context updates from this provider
    var updates: AsyncStream<ContextUpdate> { get }
}

// MARK: - Default Implementations

public extension ContextProvider {
    var requiresPermission: Bool { false }

    var hasPermission: Bool {
        get async { true }
    }

    func requestPermission() async throws -> Bool {
        true
    }
}

// MARK: - Context Provider State

/// Lifecycle state of a context provider.
public enum ContextProviderState: String, Sendable {
    case idle
    case starting
    case running
    case stopping
    case stopped
    case error
}

// MARK: - Context Provider Error

/// Errors thrown by context provider lifecycle and update operations.
public enum ContextProviderError: Error, LocalizedError {
    case permissionDenied
    case notAvailable
    case alreadyRunning
    case notRunning
    case initializationFailed(Error)
    case updateFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Permission denied for context provider"
        case .notAvailable:
            "Context provider not available on this device"
        case .alreadyRunning:
            "Context provider is already running"
        case .notRunning:
            "Context provider is not running"
        case let .initializationFailed(error):
            "Failed to initialize context provider: \(error.localizedDescription)"
        case let .updateFailed(error):
            "Failed to update context: \(error.localizedDescription)"
        }
    }
}

// MARK: - Base Context Provider

/// Base actor implementation for context providers
public actor BaseContextProvider {
    public let providerId: String
    public let displayName: String

    public private(set) var state: ContextProviderState = .idle

    private var updateContinuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?

    public var isActive: Bool {
        state == .running
    }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, continuation) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        updateContinuation = continuation
        return stream
    }

    public init(providerId: String, displayName: String) {
        self.providerId = providerId
        self.displayName = displayName
    }

    public func setState(_ newState: ContextProviderState) {
        state = newState
    }

    public func emitUpdate(_ update: ContextUpdate) {
        updateContinuation?.yield(update)
    }

    public func finish() {
        updateContinuation?.finish()
        updateContinuation = nil
        _updates = nil
    }
}

// MARK: - Context Provider Registry

/// Registry for managing all context providers
public actor ContextProviderRegistry {
    public static let shared = ContextProviderRegistry()

    private var providers: [String: any ContextProvider] = [:]
    private var activeProviders: Set<String> = []

    private init() {}

    /// Register a new context provider
    public func register(_ provider: any ContextProvider) async {
        let id = await provider.providerId
        providers[id] = provider
    }

    /// Unregister a context provider
    public func unregister(providerId: String) async {
        if let provider = providers.removeValue(forKey: providerId) {
            await provider.stop()
            activeProviders.remove(providerId)
        }
    }

    /// Get a provider by ID
    public func provider(for id: String) -> (any ContextProvider)? {
        providers[id]
    }

    /// Get all registered providers
    public func allProviders() -> [any ContextProvider] {
        Array(providers.values)
    }

    /// Get all active providers
    public func activeProvidersList() -> [any ContextProvider] {
        providers.values.filter { provider in
            activeProviders.contains { $0 == providers.first { $0.value === provider }?.key }
        }
    }

    /// Start all providers
    public func startAll() async {
        for (id, provider) in providers {
            do {
                try await provider.start()
                activeProviders.insert(id)
            } catch {
                print("Failed to start provider \(id): \(error)")
            }
        }
    }

    /// Stop all providers
    public func stopAll() async {
        for (id, provider) in providers {
            await provider.stop()
            activeProviders.remove(id)
        }
    }

    /// Start a specific provider
    public func start(providerId: String) async throws {
        guard let provider = providers[providerId] else {
            throw ContextProviderError.notAvailable
        }
        try await provider.start()
        activeProviders.insert(providerId)
    }

    /// Stop a specific provider
    public func stop(providerId: String) async {
        guard let provider = providers[providerId] else { return }
        await provider.stop()
        activeProviders.remove(providerId)
    }

    /// Check if a provider is active
    public func isActive(providerId: String) -> Bool {
        activeProviders.contains(providerId)
    }

    /// Get current context from all active providers
    public func getAllCurrentContext() async -> [ContextUpdate] {
        var updates: [ContextUpdate] = []
        for provider in providers.values where activeProviders.contains(providers.first(where: { $0.value === provider })?.key ?? "") {
            if let update = await provider.getCurrentContext() {
                updates.append(update)
            }
        }
        return updates
    }
}
