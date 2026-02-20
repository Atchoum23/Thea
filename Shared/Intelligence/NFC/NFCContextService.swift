//
//  NFCContextService.swift
//  Thea
//
//  AAF3-3: NFC Context Service — tap NFC tags to activate Thea contexts.
//  Reads NDEF tags containing thea:// URLs and routes them to focus sessions or HomeKit scenes.
//
//  Supported URL scheme:
//    thea://context/work    → activates Work focus session
//    thea://context/sleep   → activates Sleep HomeKit scene
//    thea://context/gym     → activates Gym focus session
//    thea://context/home    → activates Morning/Home HomeKit scene
//    thea://context/travel  → activates Travel focus session
//
//  Requires entitlement: com.apple.developer.nfc.readersession.formats (NDEF, TAG)
//  Requires Info.plist: NSNFCReaderUsageDescription
//

#if os(iOS)
import Foundation
import CoreNFC
import os.log

/// Allowed thea:// context URL paths — file-private constant for nonisolated access from NFC delegate.
private let nfcAllowedContextPaths: Set<String> = [
    "work", "sleep", "gym", "home", "travel", "morning", "evening", "focus"
]

/// Validates that a URL is a safe thea://context/<path> deep link.
/// File-private free function so it can be called from nonisolated NFC delegate methods.
private func validateNFCURL(_ url: URL) -> NFCContext? {
    guard url.scheme?.lowercased() == "thea",
          url.host?.lowercased() == "context" else { return nil }
    let path = url.lastPathComponent.lowercased()
    guard nfcAllowedContextPaths.contains(path) else { return nil }
    return NFCContext(rawValue: path)
}

@MainActor
final class NFCContextService: NSObject, ObservableObject {
    static let shared = NFCContextService()

    // MARK: - Published State

    @Published var lastDetectedContext: NFCContext?
    @Published var isScanning: Bool = false

    // MARK: - Private

    private var readerSession: NFCNDEFReaderSession?
    private let logger = Logger(subsystem: "app.theathe", category: "NFCContextService")

    override private init() {
        super.init()
        logger.info("NFCContextService initialized")
    }

    // MARK: - Scanning

    /// Starts an NFC NDEF reader session with user-facing alert message.
    func beginScan(alertMessage: String = "Hold your iPhone near a Thea NFC tag.") {
        guard NFCNDEFReaderSession.readingAvailable else {
            logger.warning("NFC reading not available on this device")
            return
        }
        guard !isScanning else {
            logger.info("NFC scan already in progress")
            return
        }

        readerSession = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: true)
        readerSession?.alertMessage = alertMessage
        readerSession?.begin()
        isScanning = true
        logger.info("NFC scan session started")
    }

    func cancelScan() {
        readerSession?.invalidate()
        readerSession = nil
        isScanning = false
    }

    // MARK: - Context Routing

    private func handle(context: NFCContext) async {
        lastDetectedContext = context
        logger.info("NFC context detected: \(context.rawValue)")

        switch context {
        case .sleep:
            await HomeKitAIEngine.shared.executeScene(named: "Sleep")
        case .home, .morning:
            await HomeKitAIEngine.shared.executeScene(named: "Morning")
        case .evening:
            await HomeKitAIEngine.shared.executeScene(named: "Evening")
        case .work, .focus, .gym, .travel:
            // Post notification for focus session — handled by FocusModeIntelligence / ActionButtonHandler
            NotificationCenter.default.post(
                name: .theaFocusSessionRequested,
                object: context.rawValue
            )
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCContextService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            for record in message.records {
                guard let payload = String(data: record.payload, encoding: .utf8) ??
                                   String(data: record.payload, encoding: .utf8),
                      let url = URL(string: payload.trimmingCharacters(in: .whitespacesAndNewlines)),
                      let context = validateNFCURL(url) else { continue }

                Task { @MainActor in
                    await self.handle(context: context)
                }
                session.alertMessage = "Thea context '\(context.rawValue)' activated!"
                return
            }
        }
        session.alertMessage = "No Thea context found on this tag."
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            // NFCReaderError.readerSessionInvalidationErrorFirstNDEFTagRead (201) is expected after success
            if let nfcError = error as? NFCReaderError,
               nfcError.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
                self.logger.info("NFC session completed normally (first read)")
            } else {
                self.logger.error("NFC session invalidated: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        Task { @MainActor in
            self.logger.info("NFC reader session became active")
        }
    }
}

// MARK: - NFCContext Enum

enum NFCContext: String, CaseIterable, Sendable {
    case work
    case sleep
    case gym
    case home
    case morning
    case evening
    case travel
    case focus

    var displayName: String {
        switch self {
        case .work:    return "Work Mode"
        case .sleep:   return "Sleep Mode"
        case .gym:     return "Gym Session"
        case .home:    return "Home"
        case .morning: return "Morning Routine"
        case .evening: return "Evening Wind-Down"
        case .travel:  return "Travel Mode"
        case .focus:   return "Deep Focus"
        }
    }

    var systemIcon: String {
        switch self {
        case .work:    return "briefcase.fill"
        case .sleep:   return "moon.fill"
        case .gym:     return "figure.run"
        case .home:    return "house.fill"
        case .morning: return "sunrise.fill"
        case .evening: return "sunset.fill"
        case .travel:  return "airplane"
        case .focus:   return "brain.head.profile"
        }
    }

    /// The NFC tag URL to encode on a physical tag.
    var tagURL: URL {
        URL(string: "thea://context/\(rawValue)")!
    }
}

// theaFocusSessionRequested is defined in ActionButtonHandler.swift (public extension Notification.Name).
#endif
