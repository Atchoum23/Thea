//
//  EndpointSecurityObserver+Helpers.swift
//  Thea
//
//  Created by Thea
//  Helper and utility methods for EndpointSecurityObserver
//

// swiftlint:disable large_tuple
#if os(macOS) && ENABLE_ENDPOINT_SECURITY
    import EndpointSecurity
    import Foundation

    @available(macOS 11.0, *)
    extension EndpointSecurityObserver {
        // MARK: - String Helpers

        func getString(_ esString: es_string_token_t) -> String {
            if esString.length > 0, let data = esString.data {
                return String(cString: data)
            }
            return ""
        }

        func getUsernameFromAuditToken(_ token: audit_token_t) -> String {
            let uid = audit_token_to_euid(token)
            if let pwd = getpwuid(uid) {
                return String(cString: pwd.pointee.pw_name)
            }
            return "uid:\(uid)"
        }

        func getStatfsString(_ array: inout (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
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
                                             Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                             Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) -> String
        {
            withUnsafePointer(to: &array) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 1024) { cString in
                    String(cString: cString)
                }
            }
        }

        func getString(_ tuple: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)) -> String
        {
            var mutableTuple = tuple
            return withUnsafePointer(to: &mutableTuple) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { cString in
                    String(cString: cString)
                }
            }
        }

        func getString(_ array: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
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

        func getArguments(_ exec: es_event_exec_t) -> [String] {
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
        func getFsTypeString(_ array: inout (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8,
                                             Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) -> String
        {
            withUnsafePointer(to: &array) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { cString in
                    String(cString: cString)
                }
            }
        }

        func logClientCreationError(_ result: es_new_client_result_t) {
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

        func addToHistory(_ event: EndpointSecurityEvent) {
            recentEvents.append(event)
            if recentEvents.count > maxEventHistory {
                recentEvents = Array(recentEvents.suffix(maxEventHistory / 2))
            }
        }

        public func getRecentEvents(limit: Int = 100) -> [EndpointSecurityEvent] {
            Array(recentEvents.suffix(limit))
        }
    }
#endif
// swiftlint:enable large_tuple
