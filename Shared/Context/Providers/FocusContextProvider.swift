import Foundation
import os.log
#if canImport(Intents)
    import Intents
#endif

// MARK: - Focus Context Provider

/// Provides Focus mode context (Do Not Disturb, Work, Personal, etc.)
public actor FocusContextProvider: ContextProvider {
    public let providerId = "focus"
    public let displayName = "Focus Mode"

    private let logger = Logger(subsystem: "app.thea", category: "FocusProvider")

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?
    private var notificationObserver: Any?

    private var currentFocusStatus: FocusContext = .init()

    public var isActive: Bool { state == .running }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        #if os(iOS)
            // Request focus status authorization
            let center = INFocusStatusCenter.default
            Task {
                let status = await center.requestAuthorization()
                await self.handleAuthorizationStatus(status)
            }
        #endif

        // Start periodic updates
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchFocusStatus()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break // Task cancelled — stop periodic updates
                }
            }
        }

        state = .running
        logger.info("Focus provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Focus provider stopped")
    }

    public func getCurrentContext() async -> ContextUpdate? {
        await fetchFocusStatus()
        return ContextUpdate(
            providerId: providerId,
            updateType: .focus(currentFocusStatus),
            priority: .normal
        )
    }

    // MARK: - Private Methods

    #if os(iOS)
        private func handleAuthorizationStatus(_ status: INFocusStatusAuthorizationStatus) async {
            switch status {
            case .authorized:
                logger.info("Focus status authorized")
                await fetchFocusStatus()
            case .denied:
                logger.warning("Focus status authorization denied")
            case .notDetermined:
                logger.info("Focus status authorization not determined")
            case .restricted:
                logger.warning("Focus status authorization restricted")
            @unknown default:
                break
            }
        }
    #endif

    private func fetchFocusStatus() async {
        #if os(iOS)
            let center = INFocusStatusCenter.default
            let focusStatus = center.focusStatus

            let isActive = focusStatus.isFocused ?? false

            currentFocusStatus = FocusContext(
                isActive: isActive,
                modeName: isActive ? "Focus" : "None",
                modeIdentifier: nil,
                startTime: nil,
                endTime: nil,
                allowedApps: nil,
                silencedApps: nil
            )

            let update = ContextUpdate(
                providerId: providerId,
                updateType: .focus(currentFocusStatus),
                priority: isActive ? .normal : .low
            )
            continuation?.yield(update)
        #elseif os(macOS)
            // On macOS, check Do Not Disturb status
            let isDoNotDisturb = await checkMacOSDoNotDisturb()

            currentFocusStatus = FocusContext(
                isActive: isDoNotDisturb,
                modeName: isDoNotDisturb ? "Do Not Disturb" : "None",
                modeIdentifier: nil,
                startTime: nil,
                endTime: nil,
                allowedApps: nil,
                silencedApps: nil
            )

            let update = ContextUpdate(
                providerId: providerId,
                updateType: .focus(currentFocusStatus),
                priority: .normal
            )
            continuation?.yield(update)
        #endif
    }

    #if os(macOS)
        private func checkMacOSDoNotDisturb() async -> Bool {
            // Check DND status via notification center defaults
            // This is a simplified check - full implementation would use private APIs or observe system state
            let defaults = UserDefaults(suiteName: "com.apple.notificationcenterui")
            return defaults?.bool(forKey: "doNotDisturb") ?? false
        }
    #endif
}
