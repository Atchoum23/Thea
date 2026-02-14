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

// swiftlint:disable large_tuple
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

        private let logger = Logger(subsystem: "app.thea.security", category: "EndpointSecurity")
        private var client: OpaquePointer?
        private var isRunning = false

        private let eventQueue = DispatchQueue(label: "app.thea.endpoint-security", qos: .userInitiated)

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

        private var recentEvents: [EndpointSecurityEvent] = []
        private let maxEventHistory = 1000

        private init() {}

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

        // MARK: - Event Handling

        private func handleMessage(_ message: UnsafePointer<es_message_t>) {
            let msg = message.pointee

            eventQueue.async { [weak self] in
                guard let self else { return }

                switch msg.event_type {
                case ES_EVENT_TYPE_NOTIFY_EXEC:
                    self.handleExecEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_EXIT:
                    self.handleExitEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_CREATE:
                    self.handleFileCreateEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_UNLINK:
                    self.handleFileDeleteEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_RENAME:
                    self.handleFileRenameEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_WRITE:
                    self.handleFileWriteEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_MOUNT:
                    self.handleMountEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_UNMOUNT:
                    self.handleUnmountEvent(msg)

                case ES_EVENT_TYPE_NOTIFY_SIGNAL:
                    self.handleSignalEvent(msg)

                default:
                    break
                }
            }
        }

        // MARK: - Process Events

        private func handleExecEvent(_ msg: es_message_t) {
            let process = msg.process.pointee
            let exec = msg.event.exec

            let event = ProcessExecEvent(
                timestamp: Date(),
                pid: audit_token_to_pid(process.audit_token),
                ppid: audit_token_to_pid(process.parent_audit_token),
                processPath: getString(exec.target.pointee.executable.pointee.path),
                arguments: getArguments(exec),
                environment: [:], // Can be extracted if needed
                username: getUsernameFromAuditToken(process.audit_token),
                signingId: getString(process.signing_id),
                teamId: getString(process.team_id),
                isPlatformBinary: process.is_platform_binary
            )

            addToHistory(.processExec(event))
            onProcessExec?(event)
        }

        private func handleExitEvent(_ msg: es_message_t) {
            let process = msg.process.pointee

            let event = ProcessExitEvent(
                timestamp: Date(),
                pid: audit_token_to_pid(process.audit_token),
                processPath: getString(process.executable.pointee.path),
                exitStatus: msg.event.exit.stat
            )

            addToHistory(.processExit(event))
            onProcessExit?(event)
        }

        // MARK: - File Events

        private func handleFileCreateEvent(_ msg: es_message_t) {
            let create = msg.event.create

            let path: String = if create.destination_type == ES_DESTINATION_TYPE_NEW_PATH {
                getString(create.destination.new_path.dir.pointee.path) + "/" +
                    getString(create.destination.new_path.filename)
            } else {
                getString(create.destination.existing_file.pointee.path)
            }

            let event = FileEvent(
                timestamp: Date(),
                path: path,
                pid: audit_token_to_pid(msg.process.pointee.audit_token),
                processPath: getString(msg.process.pointee.executable.pointee.path),
                operation: .create
            )

            addToHistory(.fileEvent(event))
            onFileCreate?(event)
        }

        private func handleFileDeleteEvent(_ msg: es_message_t) {
            let unlink = msg.event.unlink

            let event = FileEvent(
                timestamp: Date(),
                path: getString(unlink.target.pointee.path),
                pid: audit_token_to_pid(msg.process.pointee.audit_token),
                processPath: getString(msg.process.pointee.executable.pointee.path),
                operation: .delete
            )

            addToHistory(.fileEvent(event))
            onFileDelete?(event)
        }

        private func handleFileRenameEvent(_ msg: es_message_t) {
            let rename = msg.event.rename

            let sourcePath = getString(rename.source.pointee.path)
            let destPath: String = if rename.destination_type == ES_DESTINATION_TYPE_NEW_PATH {
                getString(rename.destination.new_path.dir.pointee.path) + "/" +
                    getString(rename.destination.new_path.filename)
            } else {
                getString(rename.destination.existing_file.pointee.path)
            }

            let event = FileRenameEvent(
                timestamp: Date(),
                sourcePath: sourcePath,
                destinationPath: destPath,
                pid: audit_token_to_pid(msg.process.pointee.audit_token),
                processPath: getString(msg.process.pointee.executable.pointee.path)
            )

            addToHistory(.fileRename(event))
            onFileRename?(event)
        }

        private func handleFileWriteEvent(_ msg: es_message_t) {
            let write = msg.event.write

            let event = FileEvent(
                timestamp: Date(),
                path: getString(write.target.pointee.path),
                pid: audit_token_to_pid(msg.process.pointee.audit_token),
                processPath: getString(msg.process.pointee.executable.pointee.path),
                operation: .write
            )

            addToHistory(.fileEvent(event))
            onFileWrite?(event)
        }

        // MARK: - Mount Events

        private func handleMountEvent(_ msg: es_message_t) {
            let mount = msg.event.mount
            let statfsPtr = mount.statfs

            let mountPoint = withUnsafePointer(to: statfsPtr.pointee.f_mntonname) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            let volumeName = withUnsafePointer(to: statfsPtr.pointee.f_mntfromname) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            let fsType = withUnsafePointer(to: statfsPtr.pointee.f_fstypename) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) { String(cString: $0) }
            }

            let event = MountEvent(
                timestamp: Date(),
                mountPoint: mountPoint,
                volumeName: volumeName,
                fileSystemType: fsType,
                isMounting: true
            )

            addToHistory(.mount(event))
            onMountEvent?(event)
        }

        private func handleUnmountEvent(_ msg: es_message_t) {
            let unmount = msg.event.unmount
            let statfsPtr = unmount.statfs

            let mountPoint = withUnsafePointer(to: statfsPtr.pointee.f_mntonname) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            let volumeName = withUnsafePointer(to: statfsPtr.pointee.f_mntfromname) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            let fsType = withUnsafePointer(to: statfsPtr.pointee.f_fstypename) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) { String(cString: $0) }
            }

            let event = MountEvent(
                timestamp: Date(),
                mountPoint: mountPoint,
                volumeName: volumeName,
                fileSystemType: fsType,
                isMounting: false
            )

            addToHistory(.mount(event))
            onMountEvent?(event)
        }

        // MARK: - Signal Events

        private func handleSignalEvent(_ msg: es_message_t) {
            let signal = msg.event.signal

            let event = SignalEvent(
                timestamp: Date(),
                signal: signal.sig,
                targetPid: audit_token_to_pid(signal.target.pointee.audit_token),
                sourcePid: audit_token_to_pid(msg.process.pointee.audit_token),
                sourceProcessPath: getString(msg.process.pointee.executable.pointee.path)
            )

            addToHistory(.signal(event))
            onSignalEvent?(event)
        }

        // MARK: - Helpers

        private func getString(_ esString: es_string_token_t) -> String {
            if esString.length > 0, let data = esString.data {
                return String(cString: data)
            }
            return ""
        }

        private func getUsernameFromAuditToken(_ token: audit_token_t) -> String {
            let uid = audit_token_to_euid(token)
            if let pwd = getpwuid(uid) {
                return String(cString: pwd.pointee.pw_name)
            }
            return "uid:\(uid)"
        }

        private func getStatfsString(_ array: inout (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) -> String
        {
            withUnsafePointer(to: &array) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 1024) { cString in
                    String(cString: cString)
                }
            }
        }

        private func getString(_ tuple: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)) -> String
        {
            var mutableTuple = tuple
            return withUnsafePointer(to: &mutableTuple) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { cString in
                    String(cString: cString)
                }
            }
        }

        private func getString(_ array: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                         CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)) -> String
        {
            var mutableArray = array
            return withUnsafePointer(to: &mutableArray) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 1024) { cString in
                    String(cString: cString)
                }
            }
        }

        private func getArguments(_ exec: es_event_exec_t) -> [String] {
            var arguments: [String] = []
            var execCopy = exec
            let argc = es_exec_arg_count(&execCopy)

            for i in 0 ..< argc {
                let arg = es_exec_arg(&execCopy, i)
                arguments.append(getString(arg))
            }

            return arguments
        }

        // Helper for f_fstypename (MFSNAMELEN = 16)
        private func getFsTypeString(_ array: inout (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                                     Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) -> String
        {
            withUnsafePointer(to: &array) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { cString in
                    String(cString: cString)
                }
            }
        }

        private func logClientCreationError(_ result: es_new_client_result_t) {
            switch result {
            case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
                logger.error("ES client creation failed: Not entitled. Add com.apple.developer.endpoint-security.client entitlement.")
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
                logger.error("ES client creation failed: Not permitted. Grant Full Disk Access in System Preferences.")
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
                logger.error("ES client creation failed: Not privileged. Run as root or with appropriate permissions.")
            case ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS:
                logger.error("ES client creation failed: Too many clients.")
            case ES_NEW_CLIENT_RESULT_ERR_INTERNAL:
                logger.error("ES client creation failed: Internal error.")
            default:
                logger.error("ES client creation failed: Unknown error \(result.rawValue)")
            }
        }

        // MARK: - Event History

        private func addToHistory(_ event: EndpointSecurityEvent) {
            recentEvents.append(event)
            if recentEvents.count > maxEventHistory {
                recentEvents = Array(recentEvents.suffix(maxEventHistory / 2))
            }
        }

        public func getRecentEvents(limit: Int = 100) -> [EndpointSecurityEvent] {
            Array(recentEvents.suffix(limit))
        }
    }

    // Event types (EndpointSecurityEvent, ProcessExecEvent, ProcessExitEvent,
    // FileEvent, FileRenameEvent, NetworkEvent, MountEvent, SignalEvent)
    // are in EndpointSecurityTypes.swift
#endif
// swiftlint:enable large_tuple
