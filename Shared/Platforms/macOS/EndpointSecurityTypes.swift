// EndpointSecurityTypes.swift
// Supporting event types for EndpointSecurityObserver

#if os(macOS) && ENABLE_ENDPOINT_SECURITY
    import Foundation

    // MARK: - Event Types

    public enum EndpointSecurityEvent: Sendable {
        case processExec(ProcessExecEvent)
        case processExit(ProcessExitEvent)
        case fileEvent(FileEvent)
        case fileRename(FileRenameEvent)
        case network(NetworkEvent)
        case mount(MountEvent)
        case signal(SignalEvent)

        public var timestamp: Date {
            switch self {
            case let .processExec(e): e.timestamp
            case let .processExit(e): e.timestamp
            case let .fileEvent(e): e.timestamp
            case let .fileRename(e): e.timestamp
            case let .network(e): e.timestamp
            case let .mount(e): e.timestamp
            case let .signal(e): e.timestamp
            }
        }
    }

    public struct ProcessExecEvent: Sendable {
        public let timestamp: Date
        public let pid: pid_t
        public let ppid: pid_t
        public let processPath: String
        public let arguments: [String]
        public let environment: [String: String]
        public let username: String
        public let signingId: String
        public let teamId: String
        public let isPlatformBinary: Bool
    }

    public struct ProcessExitEvent: Sendable {
        public let timestamp: Date
        public let pid: pid_t
        public let processPath: String
        public let exitStatus: Int32
    }

    public struct FileEvent: Sendable {
        public let timestamp: Date
        public let path: String
        public let pid: pid_t
        public let processPath: String
        public let operation: FileOperation

        public enum FileOperation: String, Sendable {
            case create
            case delete
            case write
            case open
            case close
        }
    }

    public struct FileRenameEvent: Sendable {
        public let timestamp: Date
        public let sourcePath: String
        public let destinationPath: String
        public let pid: pid_t
        public let processPath: String
    }

    public struct NetworkEvent: Sendable {
        public let timestamp: Date
        public let pid: pid_t
        public let processPath: String
        public let remoteAddress: String
        public let remotePort: UInt16
        public let localAddress: String
        public let localPort: UInt16
        public let `protocol`: NetworkProtocol

        public enum NetworkProtocol: String, Sendable {
            case tcp
            case udp
        }
    }

    public struct MountEvent: Sendable {
        public let timestamp: Date
        public let mountPoint: String
        public let volumeName: String
        public let fileSystemType: String
        public let isMounting: Bool
    }

    public struct SignalEvent: Sendable {
        public let timestamp: Date
        public let signal: Int32
        public let targetPid: pid_t
        public let sourcePid: pid_t
        public let sourceProcessPath: String

        public var signalName: String {
            switch signal {
            case SIGTERM: "SIGTERM"
            case SIGKILL: "SIGKILL"
            case SIGINT: "SIGINT"
            case SIGHUP: "SIGHUP"
            case SIGSTOP: "SIGSTOP"
            case SIGCONT: "SIGCONT"
            default: "SIG\(signal)"
            }
        }
    }
#endif
