//
//  EndpointSecurityObserver.swift
//  Thea
//
//  Created by Thea
//  Endpoint Security framework integration for deep system monitoring
//  Requires Developer ID signing and com.apple.developer.endpoint-security.client entitlement
//
//  NOTE: This feature is disabled by default as it requires special entitlements from Apple.
//  To enable, add ENABLE_ENDPOINT_SECURITY to your Swift compiler flags.
//

#if os(macOS) && ENABLE_ENDPOINT_SECURITY
    import EndpointSecurity
    import Foundation
    import os.log

    // MARK: - Endpoint Security Observer

    /// Observes system events via Endpoint Security framework
    /// Provides deep visibility into process execution, file operations, and system events
    /// NOTE: Requires Developer ID signing and special entitlement from Apple
    @available(macOS 11.0, *)
    public final class EndpointSecurityObserver: @unchecked Sendable {
        public static let shared = EndpointSecurityObserver()

        let logger = Logger(subsystem: "app.thea.security", category: "EndpointSecurity")
        var client: OpaquePointer?
        var isRunning = false

        let eventQueue = DispatchQueue(label: "app.thea.endpoint-security", qos: .userInitiated)

        // MARK: - Callbacks

        public var onProcessExec: ((ProcessExecEvent) -> Void)?
        public var onProcessExit: ((ProcessExitEvent) -> Void)?
        public var onFileCreate: ((FileEvent) -> Void)?
        public var onFileDelete: ((FileEvent) -> Void)?
        public var onFileRename: ((FileRenameEvent) -> Void)?
        public var onFileWrite: ((FileEvent) -> Void)?
        public var onNetworkConnect: ((NetworkEvent) -> Void)?
        public var onMountEvent: ((MountEvent) -> Void)?
        public var onSignalEvent: ((SignalEvent) -> Void)?

        // MARK: - Event History

        var recentEvents: [EndpointSecurityEvent] = []
        let maxEventHistory = 1000

        init() {}

        // MARK: - Lifecycle

        public func start() -> Bool {
            guard !isRunning else {
                logger.warning("EndpointSecurityObserver already running")
                return true
            }

            logger.info("Starting EndpointSecurityObserver")

            // Create ES client
            var newClient: OpaquePointer?
            let result = es_new_client(&newClient) { [weak self] _, message in
                self?.handleMessage(message)
            }

            guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let client = newClient else {
                logger.error("Failed to create ES client: \(String(describing: result))")
                logClientCreationError(result)
                return false
            }

            self.client = client

            // Subscribe to events
            let events: [es_event_type_t] = [
                ES_EVENT_TYPE_NOTIFY_EXEC,
                ES_EVENT_TYPE_NOTIFY_EXIT,
                ES_EVENT_TYPE_NOTIFY_CREATE,
                ES_EVENT_TYPE_NOTIFY_UNLINK,
                ES_EVENT_TYPE_NOTIFY_RENAME,
                ES_EVENT_TYPE_NOTIFY_WRITE,
                ES_EVENT_TYPE_NOTIFY_OPEN,
                ES_EVENT_TYPE_NOTIFY_CLOSE,
                ES_EVENT_TYPE_NOTIFY_MOUNT,
                ES_EVENT_TYPE_NOTIFY_UNMOUNT,
                ES_EVENT_TYPE_NOTIFY_SIGNAL
            ]

            let subscribeResult = es_subscribe(client, events, UInt32(events.count))
            guard subscribeResult == ES_RETURN_SUCCESS else {
                logger.error("Failed to subscribe to ES events")
                es_delete_client(client)
                self.client = nil
                return false
            }

            // Clear cache to receive all events
            es_clear_cache(client)

            isRunning = true
            logger.info("EndpointSecurityObserver started successfully")

            return true
        }

        public func stop() {
            guard isRunning, let client else { return }

            logger.info("Stopping EndpointSecurityObserver")

            es_unsubscribe_all(client)
            es_delete_client(client)
            self.client = nil
            isRunning = false

            logger.info("EndpointSecurityObserver stopped")
        }
    }
#endif
