// iMessageChannel.swift
// Thea — Native iMessage/SMS channel for MessagingHub
//
// macOS: Uses AppleScript to interact with Messages.app for sending
// and reading messages. Contacts framework for contact resolution.
// iOS: Observes notification content for iMessage notifications.

import Foundation
import Contacts
import OSLog

#if os(macOS)
import AppKit
#endif

private let imsgLogger = Logger(subsystem: "ai.thea.app", category: "iMessageChannel")

// periphery:ignore - Reserved: imsgLogger global var reserved for future feature activation
/// Native iMessage/SMS channel — no third-party dependency.
@MainActor
final class iMessageChannel: ObservableObject { // swiftlint:disable:this type_name
    // periphery:ignore - Reserved: iMessageChannel type reserved for future feature activation
    static let shared = iMessageChannel()

    // MARK: - Published State

    @Published private(set) var isConnected = false
    @Published private(set) var recentContacts: [iMessageContact] = []
    @Published private(set) var lastSentAt: Date?
    @Published private(set) var sentCount = 0

    // MARK: - Configuration

    var enabled = true
    var autoReplyEnabled = false
    var contactCacheMaxAge: TimeInterval = 3600

    // MARK: - Private

    private var contactStore = CNContactStore()
    private var lastContactRefresh: Date?

    // MARK: - Init

    private init() {}

    // MARK: - Connection

    func connect() async {
        guard enabled else { return }

        // Request Contacts access
        let authorized = await requestContactsAccess()
        if authorized {
            await refreshContacts()
        }

        #if os(macOS)
        // Verify Messages.app is available
        let available = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.MobileSMS"
        ) != nil
        isConnected = available
        #else
        isConnected = true
        #endif

        if isConnected {
            // Register with MessagingHub
            let channel = RegisteredChannel(
                type: .iMessage,
                name: "iMessage",
                status: .connected,
                isEnabled: enabled,
                autoReplyEnabled: autoReplyEnabled
            )
            MessagingHub.shared.registerChannel(channel)
            imsgLogger.info("iMessage channel connected")
        }
    }

    func disconnect() {
        isConnected = false
        MessagingHub.shared.updateChannelStatus(.iMessage, name: "iMessage", status: .disconnected)
        imsgLogger.info("iMessage channel disconnected")
    }

    // MARK: - Send Message

    #if os(macOS)
    /// Send a message via Messages.app using AppleScript.
    func sendMessage(to recipient: String, text: String) async -> Bool {
        guard isConnected else {
            imsgLogger.warning("Cannot send — iMessage not connected")
            return false
        }

        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedRecipient = recipient
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(escapedRecipient)" of targetService
            send "\(escapedText)" to targetBuddy
        end tell
        """

        let success = executeAppleScript(script)
        if success {
            sentCount += 1
            lastSentAt = Date()
            imsgLogger.info("Sent iMessage to \(recipient)")
        }
        return success
    }

    private func executeAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            imsgLogger.error("AppleScript error: \(error)")
            return false
        }
        return true
    }
    #endif

    // MARK: - Contact Resolution

    func resolveContact(identifier: String) -> iMessageContact? {
        recentContacts.first { $0.identifier == identifier || $0.phoneNumber == identifier || $0.email == identifier }
    }

    func searchContacts(query: String) -> [iMessageContact] {
        let lower = query.lowercased()
        return recentContacts.filter {
            $0.displayName.lowercased().contains(lower) ||
            ($0.phoneNumber?.lowercased().contains(lower) ?? false) ||
            ($0.email?.lowercased().contains(lower) ?? false)
        }
    }

    // MARK: - Contacts Framework

    private func requestContactsAccess() async -> Bool {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            return granted
        } catch {
            imsgLogger.error("Contacts access denied: \(error.localizedDescription)")
            return false
        }
    }

    private func refreshContacts() async {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [iMessageContact] = []

        do {
            try contactStore.enumerateContacts(with: request) { cnContact, _ in
                let phone = cnContact.phoneNumbers.first?.value.stringValue
                let email = cnContact.emailAddresses.first?.value as String?
                let name = [cnContact.givenName, cnContact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                guard !name.isEmpty else { return }

                let contact = iMessageContact(
                    identifier: cnContact.identifier,
                    displayName: name,
                    phoneNumber: phone,
                    email: email
                )
                contacts.append(contact)
            }
        } catch {
            imsgLogger.error("Contact fetch failed: \(error.localizedDescription)")
        }

        recentContacts = contacts.sorted { $0.displayName < $1.displayName }
        lastContactRefresh = Date()
        imsgLogger.info("Loaded \(contacts.count) contacts")
    }
}

// MARK: - Contact Model

// periphery:ignore - Reserved: iMessageContact type reserved for future feature activation
struct iMessageContact: Codable, Sendable, Identifiable { // swiftlint:disable:this type_name
    let id: UUID
    let identifier: String
    let displayName: String
    let phoneNumber: String?
    let email: String?

    init(
        identifier: String,
        displayName: String,
        phoneNumber: String? = nil,
        email: String? = nil
    ) {
        self.id = UUID()
        self.identifier = identifier
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.email = email
    }
}
