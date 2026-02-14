//
//  EndpointSecurityObserver+EventHandling.swift
//  Thea
//
//  Created by Thea
//  Event handling methods for EndpointSecurityObserver
//

#if os(macOS) && ENABLE_ENDPOINT_SECURITY
    import EndpointSecurity
    import Foundation

    @available(macOS 11.0, *)
    extension EndpointSecurityObserver {
        // MARK: - Event Handling

        func handleMessage(_ message: UnsafePointer<es_message_t>) {
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
    }
#endif
