//
//  ProcessObserver.swift
//  Thea
//
//  Created by Thea
//  Deep System Awareness - Process Monitoring
//

#if os(macOS)
    import AppKit
    import Darwin
    import Foundation
    import os.log

    // Darwin constant that may not be available in all SDK versions
    private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

    // MARK: - Process Observer

    /// Monitors running processes for system-wide activity awareness
    public actor ProcessObserver {
        public static let shared = ProcessObserver()

        private let logger = Logger(subsystem: "app.thea", category: "ProcessObserver")

        // State
        private var isRunning = false
        private var pollTask: Task<Void, Never>?

        // Process tracking
        private var runningProcesses: [pid_t: AppProcessInfo] = [:]
        private var processHistory: [ProcessEvent] = []
        private let maxHistorySize = 500

        // Callbacks
        private var onProcessLaunched: ((AppProcessInfo) -> Void)?
        private var onProcessTerminated: ((AppProcessInfo) -> Void)?
        private var onActiveProcessChanged: ((AppProcessInfo) -> Void)?

        // Workspace observers (accessed only from MainActor)
        nonisolated(unsafe) private var launchObserver: NSObjectProtocol?
        nonisolated(unsafe) private var terminateObserver: NSObjectProtocol?
        nonisolated(unsafe) private var activateObserver: NSObjectProtocol?

        private init() {}

        // MARK: - Public API

        /// Start observing process events
        public func start() async {
            guard !isRunning else { return }

            isRunning = true
            logger.info("Starting process observer")

            // Initial snapshot of running apps
            await snapshotRunningApps()

            // Start workspace observers on main thread
            await MainActor.run {
                setupWorkspaceObservers()
            }

            // Start polling for non-app processes
            startPolling()
        }

        /// Stop observing process events
        public func stop() async {
            guard isRunning else { return }

            isRunning = false
            pollTask?.cancel()
            pollTask = nil

            await MainActor.run {
                removeWorkspaceObservers()
            }

            logger.info("Stopped process observer")
        }

        /// Set callback for process launch
        public func onLaunch(_ callback: @escaping (AppProcessInfo) -> Void) {
            onProcessLaunched = callback
        }

        /// Set callback for process termination
        public func onTerminate(_ callback: @escaping (AppProcessInfo) -> Void) {
            onProcessTerminated = callback
        }

        /// Set callback for active process change
        public func onActivate(_ callback: @escaping (AppProcessInfo) -> Void) {
            onActiveProcessChanged = callback
        }

        /// Get all running processes
        public func getRunningProcesses() -> [AppProcessInfo] {
            Array(runningProcesses.values)
        }

        /// Get running apps (GUI processes)
        public func getRunningApps() -> [AppProcessInfo] {
            runningProcesses.values.filter(\.isApp)
        }

        /// Get process by PID
        public func getProcess(pid: pid_t) -> AppProcessInfo? {
            runningProcesses[pid]
        }

        /// Get process history
        public func getHistory(limit: Int = 100) -> [ProcessEvent] {
            Array(processHistory.suffix(limit))
        }

        /// Get processes by bundle identifier
        public func getProcesses(bundleIdentifier: String) -> [AppProcessInfo] {
            runningProcesses.values.filter { $0.bundleIdentifier == bundleIdentifier }
        }

        /// Get the frontmost app
        nonisolated public func getFrontmostApp() -> AppProcessInfo? {
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
            return createAppProcessInfo(from: app)
        }

        /// Get CPU usage for a process
        nonisolated public func getCPUUsage(pid: pid_t) -> Double? {
            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.stride

            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

            guard result == size else { return nil }

            // Calculate approximate CPU usage
            let totalTime = Double(info.pti_total_user + info.pti_total_system)
            return totalTime / 1_000_000_000 // Convert from nanoseconds
        }

        /// Get memory usage for a process
        nonisolated public func getMemoryUsage(pid: pid_t) -> UInt64? {
            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.stride

            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

            guard result == size else { return nil }

            return info.pti_resident_size
        }

        // MARK: - Private Methods

        @MainActor
        private func setupWorkspaceObservers() {
            let workspace = NSWorkspace.shared

            launchObserver = workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract Sendable data from notification
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                let pid = app.processIdentifier
                let bundleId = app.bundleIdentifier
                let name = app.localizedName
                let launchDate = app.launchDate

                Task {
                    await self?.handleAppLaunchInfo(pid: pid, bundleId: bundleId, name: name, launchDate: launchDate)
                }
            }

            terminateObserver = workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                let pid = app.processIdentifier
                let bundleId = app.bundleIdentifier
                let name = app.localizedName

                Task {
                    await self?.handleAppTerminateInfo(pid: pid, bundleId: bundleId, name: name)
                }
            }

            activateObserver = workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                let pid = app.processIdentifier
                let bundleId = app.bundleIdentifier
                let name = app.localizedName

                Task {
                    await self?.handleAppActivateInfo(pid: pid, bundleId: bundleId, name: name)
                }
            }
        }

        @MainActor
        private func removeWorkspaceObservers() {
            let center = NSWorkspace.shared.notificationCenter

            if let observer = launchObserver {
                center.removeObserver(observer)
            }
            if let observer = terminateObserver {
                center.removeObserver(observer)
            }
            if let observer = activateObserver {
                center.removeObserver(observer)
            }

            launchObserver = nil
            terminateObserver = nil
            activateObserver = nil
        }

        private func snapshotRunningApps() async {
            let apps = await MainActor.run {
                NSWorkspace.shared.runningApplications
            }

            for app in apps {
                let info = createAppProcessInfo(from: app)
                runningProcesses[app.processIdentifier] = info
            }

            logger.info("Snapshot: \(apps.count) running applications")
        }

        nonisolated private func createAppProcessInfo(from app: NSRunningApplication) -> AppProcessInfo {
            AppProcessInfo(
                pid: app.processIdentifier,
                name: app.localizedName ?? app.executableURL?.lastPathComponent ?? "Unknown",
                bundleIdentifier: app.bundleIdentifier,
                executablePath: app.executableURL?.path,
                isApp: true,
                isActive: app.isActive,
                isHidden: app.isHidden,
                launchDate: app.launchDate,
                ownerUID: nil
            )
        }

        private func handleAppLaunchInfo(pid: pid_t, bundleId: String?, name: String?, launchDate: Date?) async {
            let info = AppProcessInfo(
                pid: pid,
                name: name ?? "Unknown",
                bundleIdentifier: bundleId,
                executablePath: nil,
                isApp: true,
                isActive: false,
                isHidden: false,
                launchDate: launchDate,
                ownerUID: nil
            )
            runningProcesses[pid] = info

            let event = ProcessEvent(
                type: .launched,
                process: info
            )
            addToHistory(event)

            onProcessLaunched?(info)
            logger.debug("App launched: \(info.name)")
        }

        private func handleAppTerminateInfo(pid: pid_t, bundleId: String?, name: String?) async {
            let info = runningProcesses[pid] ?? AppProcessInfo(
                pid: pid,
                name: name ?? "Unknown",
                bundleIdentifier: bundleId,
                executablePath: nil,
                isApp: true,
                isActive: false,
                isHidden: false,
                launchDate: nil,
                ownerUID: nil
            )
            runningProcesses.removeValue(forKey: pid)

            let event = ProcessEvent(
                type: .terminated,
                process: info
            )
            addToHistory(event)

            onProcessTerminated?(info)
            logger.debug("App terminated: \(info.name)")
        }

        private func handleAppActivateInfo(pid: pid_t, bundleId: String?, name: String?) async {
            let info = AppProcessInfo(
                pid: pid,
                name: name ?? "Unknown",
                bundleIdentifier: bundleId,
                executablePath: nil,
                isApp: true,
                isActive: true,
                isHidden: false,
                launchDate: nil,
                ownerUID: nil
            )

            // Update active state in running processes
            for (existingPid, var process) in runningProcesses {
                process.isActive = (existingPid == pid)
                runningProcesses[existingPid] = process
            }

            let event = ProcessEvent(
                type: .activated,
                process: info
            )
            addToHistory(event)

            onActiveProcessChanged?(info)
        }

        private func startPolling() {
            pollTask = Task { [weak self] in
                while let self, await self.isRunning {
                    await self.pollSystemProcesses()
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }

        private func pollSystemProcesses() async {
            // Get list of all PIDs
            var pids = [pid_t](repeating: 0, count: 1024)
            let count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.stride * pids.count))

            guard count > 0 else { return }

            let pidCount = Int(count) / MemoryLayout<pid_t>.stride

            // Track which PIDs we've seen
            var seenPids = Set<pid_t>()

            for i in 0 ..< pidCount {
                let pid = pids[i]
                guard pid > 0 else { continue }

                seenPids.insert(pid)

                // Skip if we already know about this process
                if runningProcesses[pid] != nil { continue }

                // Get process name
                var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
                let bufferSize = UInt32(pathBuffer.count)
                let pathResult = Darwin.proc_pidpath(pid, &pathBuffer, bufferSize)

                if pathResult > 0 {
                    // Convert CChar array to String
                    let pathData = pathBuffer.withUnsafeBufferPointer { buffer in
                        buffer.prefix { $0 != 0 }
                    }
                    let path = String(decoding: pathData.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                    let name = (path as NSString).lastPathComponent

                    // Get UID
                    var info = proc_bsdinfo()
                    let infoResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.stride))

                    let uid: uid_t? = infoResult > 0 ? info.pbi_uid : nil

                    let processInfo = AppProcessInfo(
                        pid: pid,
                        name: name,
                        bundleIdentifier: nil,
                        executablePath: path,
                        isApp: false,
                        isActive: false,
                        isHidden: false,
                        launchDate: nil,
                        ownerUID: uid
                    )

                    runningProcesses[pid] = processInfo
                }
            }

            // Remove terminated processes
            let terminatedPids = Set(runningProcesses.keys).subtracting(seenPids)
            for pid in terminatedPids {
                if let info = runningProcesses.removeValue(forKey: pid), !info.isApp {
                    let event = ProcessEvent(type: .terminated, process: info)
                    addToHistory(event)
                }
            }
        }

        private func addToHistory(_ event: ProcessEvent) {
            processHistory.append(event)
            if processHistory.count > maxHistorySize {
                processHistory.removeFirst(processHistory.count - maxHistorySize)
            }
        }
    }

    // MARK: - Data Types

    public struct AppProcessInfo: Sendable, Equatable {
        public let pid: pid_t
        public let name: String
        public let bundleIdentifier: String?
        public let executablePath: String?
        public let isApp: Bool
        public var isActive: Bool
        public let isHidden: Bool
        public let launchDate: Date?
        public let ownerUID: uid_t?
        public let timestamp: Date

        public init(
            pid: pid_t,
            name: String,
            bundleIdentifier: String?,
            executablePath: String?,
            isApp: Bool,
            isActive: Bool,
            isHidden: Bool,
            launchDate: Date?,
            ownerUID: uid_t?
        ) {
            self.pid = pid
            self.name = name
            self.bundleIdentifier = bundleIdentifier
            self.executablePath = executablePath
            self.isApp = isApp
            self.isActive = isActive
            self.isHidden = isHidden
            self.launchDate = launchDate
            self.ownerUID = ownerUID
            timestamp = Date()
        }

        public static func == (lhs: AppProcessInfo, rhs: AppProcessInfo) -> Bool {
            lhs.pid == rhs.pid && lhs.name == rhs.name
        }
    }

    public struct ProcessEvent: Sendable {
        public let type: ProcessEventType
        public let process: AppProcessInfo
        public let timestamp = Date()
    }

    public enum ProcessEventType: String, Sendable {
        case launched
        case terminated
        case activated
        case deactivated
    }

    // MARK: - proc_pidinfo declarations

    private let PROC_ALL_PIDS: UInt32 = 1
    private let PROC_PIDTBSDINFO: Int32 = 3
    private let PROC_PIDTASKINFO: Int32 = 4

    // swiftlint:disable large_tuple
    private struct proc_bsdinfo {
        var pbi_flags: UInt32 = 0
        var pbi_status: UInt32 = 0
        var pbi_xstatus: UInt32 = 0
        var pbi_pid: UInt32 = 0
        var pbi_ppid: UInt32 = 0
        var pbi_uid: uid_t = 0
        var pbi_gid: gid_t = 0
        var pbi_ruid: uid_t = 0
        var pbi_rgid: gid_t = 0
        var pbi_svuid: uid_t = 0
        var pbi_svgid: gid_t = 0
        var rfu_1: UInt32 = 0
        var pbi_comm: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var pbi_name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var pbi_nfiles: UInt32 = 0
        var pbi_pgid: UInt32 = 0
        var pbi_pjobc: UInt32 = 0
        var e_tdev: UInt32 = 0
        var e_tpgid: UInt32 = 0
        var pbi_nice: Int32 = 0
        var pbi_start_tvsec: UInt64 = 0
        var pbi_start_tvusec: UInt64 = 0
    }

    private struct proc_taskinfo {
        var pti_virtual_size: UInt64 = 0
        var pti_resident_size: UInt64 = 0
        var pti_total_user: UInt64 = 0
        var pti_total_system: UInt64 = 0
        var pti_threads_user: UInt64 = 0
        var pti_threads_system: UInt64 = 0
        var pti_policy: Int32 = 0
        var pti_faults: Int32 = 0
        var pti_pageins: Int32 = 0
        var pti_cow_faults: Int32 = 0
        var pti_messages_sent: Int32 = 0
        var pti_messages_received: Int32 = 0
        var pti_syscalls_mach: Int32 = 0
        var pti_syscalls_unix: Int32 = 0
        var pti_csw: Int32 = 0
        var pti_threadnum: Int32 = 0
        var pti_numrunning: Int32 = 0
        var pti_priority: Int32 = 0
    }

    // swiftlint:enable large_tuple

    @_silgen_name("proc_listpids")
    private func proc_listpids(_ type: UInt32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

    @_silgen_name("proc_pidpath")
    private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>?, _ buffersize: UInt32) -> Int32

    @_silgen_name("proc_pidinfo")
    private func proc_pidinfo(_ pid: Int32, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32
#endif
