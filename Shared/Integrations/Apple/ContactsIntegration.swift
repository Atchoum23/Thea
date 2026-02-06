// ContactsIntegration.swift
// Thea V2
//
// Deep integration with Apple Contacts framework
// Provides full CRUD operations, search, and group management

import Foundation
import OSLog

#if canImport(Contacts)
import Contacts
#endif

// MARK: - Contact Models

/// Represents a contact in the system
public struct TheaContact: Identifiable, Sendable, Codable {
    public let id: String
    public var givenName: String
    public var familyName: String
    public var middleName: String?
    public var nickname: String?
    public var organizationName: String?
    public var jobTitle: String?
    public var departmentName: String?
    public var note: String?
    public var birthday: DateComponents?
    public var imageData: Data?
    public var phoneNumbers: [LabeledValue<String>]
    public var emailAddresses: [LabeledValue<String>]
    public var postalAddresses: [LabeledValue<PostalAddress>]
    public var urlAddresses: [LabeledValue<String>]
    public var socialProfiles: [LabeledValue<ContactSocialProfile>]
    public var instantMessageAddresses: [LabeledValue<InstantMessage>]
    public var relations: [LabeledValue<String>]

    public var fullName: String {
        [givenName, middleName, familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public init(
        id: String = UUID().uuidString,
        givenName: String = "",
        familyName: String = "",
        middleName: String? = nil,
        nickname: String? = nil,
        organizationName: String? = nil,
        jobTitle: String? = nil,
        departmentName: String? = nil,
        note: String? = nil,
        birthday: DateComponents? = nil,
        imageData: Data? = nil,
        phoneNumbers: [LabeledValue<String>] = [],
        emailAddresses: [LabeledValue<String>] = [],
        postalAddresses: [LabeledValue<PostalAddress>] = [],
        urlAddresses: [LabeledValue<String>] = [],
        socialProfiles: [LabeledValue<ContactSocialProfile>] = [],
        instantMessageAddresses: [LabeledValue<InstantMessage>] = [],
        relations: [LabeledValue<String>] = []
    ) {
        self.id = id
        self.givenName = givenName
        self.familyName = familyName
        self.middleName = middleName
        self.nickname = nickname
        self.organizationName = organizationName
        self.jobTitle = jobTitle
        self.departmentName = departmentName
        self.note = note
        self.birthday = birthday
        self.imageData = imageData
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.postalAddresses = postalAddresses
        self.urlAddresses = urlAddresses
        self.socialProfiles = socialProfiles
        self.instantMessageAddresses = instantMessageAddresses
        self.relations = relations
    }
}

/// Labeled value wrapper for contact properties
public struct LabeledValue<T: Codable & Sendable>: Codable, Sendable {
    public let label: String?
    public let value: T

    public init(label: String?, value: T) {
        self.label = label
        self.value = value
    }
}

/// Postal address for contacts
public struct PostalAddress: Codable, Sendable {
    public var street: String
    public var city: String
    public var state: String
    public var postalCode: String
    public var country: String
    public var isoCountryCode: String?
    public var subAdministrativeArea: String?
    public var subLocality: String?

    public init(
        street: String = "",
        city: String = "",
        state: String = "",
        postalCode: String = "",
        country: String = "",
        isoCountryCode: String? = nil,
        subAdministrativeArea: String? = nil,
        subLocality: String? = nil
    ) {
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.isoCountryCode = isoCountryCode
        self.subAdministrativeArea = subAdministrativeArea
        self.subLocality = subLocality
    }

    public var formatted: String {
        [street, city, state, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Social profile for contacts
public struct ContactSocialProfile: Codable, Sendable {
    public var service: String
    public var username: String
    public var urlString: String?
    public var userIdentifier: String?

    public init(
        service: String,
        username: String,
        urlString: String? = nil,
        userIdentifier: String? = nil
    ) {
        self.service = service
        self.username = username
        self.urlString = urlString
        self.userIdentifier = userIdentifier
    }
}

/// Instant message address for contacts
public struct InstantMessage: Codable, Sendable {
    public var service: String
    public var username: String

    public init(service: String, username: String) {
        self.service = service
        self.username = username
    }
}

/// Contact group
public struct TheaContactGroup: Identifiable, Sendable, Codable {
    public let id: String
    public var name: String
    public var memberCount: Int

    public init(id: String = UUID().uuidString, name: String, memberCount: Int = 0) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
    }
}

// MARK: - Search Criteria

/// Search criteria for contacts
public struct ContactSearchCriteria: Sendable {
    public var nameQuery: String?
    public var emailQuery: String?
    public var phoneQuery: String?
    public var organizationQuery: String?
    public var groupId: String?
    public var hasBirthdayThisMonth: Bool
    public var limit: Int?

    public init(
        nameQuery: String? = nil,
        emailQuery: String? = nil,
        phoneQuery: String? = nil,
        organizationQuery: String? = nil,
        groupId: String? = nil,
        hasBirthdayThisMonth: Bool = false,
        limit: Int? = nil
    ) {
        self.nameQuery = nameQuery
        self.emailQuery = emailQuery
        self.phoneQuery = phoneQuery
        self.organizationQuery = organizationQuery
        self.groupId = groupId
        self.hasBirthdayThisMonth = hasBirthdayThisMonth
        self.limit = limit
    }

    public static func byName(_ name: String) -> ContactSearchCriteria {
        ContactSearchCriteria(nameQuery: name)
    }

    public static func byEmail(_ email: String) -> ContactSearchCriteria {
        ContactSearchCriteria(emailQuery: email)
    }

    public static func byPhone(_ phone: String) -> ContactSearchCriteria {
        ContactSearchCriteria(phoneQuery: phone)
    }
}

// MARK: - Contacts Integration Actor

/// Actor for managing contact operations
/// Thread-safe access to Contacts framework
@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
public actor ContactsIntegration {
    public static let shared = ContactsIntegration()

    private let logger = Logger(subsystem: "com.thea.integrations", category: "Contacts")

    #if canImport(Contacts)
    private let store = CNContactStore()
    #endif

    private init() {}

    // MARK: - Authorization

    /// Check current authorization status
    public var authorizationStatus: ContactAuthorizationStatus {
        #if canImport(Contacts)
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        case .limited:
            return .limited
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    /// Request access to contacts
    public func requestAccess() async -> Bool {
        #if canImport(Contacts)
        do {
            let granted = try await store.requestAccess(for: .contacts)
            logger.info("Contact access \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Failed to request contact access: \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Fetch Operations

    /// Fetch all contacts
    public func fetchAllContacts() async throws -> [TheaContact] {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let keysToFetch = contactKeysToFetch
        let request = CNContactFetchRequest(keysToFetch: keysToFetch as [CNKeyDescriptor])

        var contacts: [TheaContact] = []

        try store.enumerateContacts(with: request) { cnContact, _ in
            let contact = self.convertToTheaContact(cnContact)
            contacts.append(contact)
        }

        logger.info("Fetched \(contacts.count) contacts")
        return contacts
        #else
        throw ContactsError.unavailable
        #endif
    }

    /// Fetch contact by identifier
    public func fetchContact(identifier: String) async throws -> TheaContact? {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let keysToFetch = contactKeysToFetch

        do {
            let cnContact = try store.unifiedContact(
                withIdentifier: identifier,
                keysToFetch: keysToFetch as [CNKeyDescriptor]
            )
            return convertToTheaContact(cnContact)
        } catch {
            logger.warning("Contact not found: \(identifier)")
            return nil
        }
        #else
        throw ContactsError.unavailable
        #endif
    }

    /// Search contacts by criteria
    public func searchContacts(criteria: ContactSearchCriteria) async throws -> [TheaContact] {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        var contacts: [TheaContact] = []
        let keysToFetch = contactKeysToFetch

        // Search by name
        if let nameQuery = criteria.nameQuery, !nameQuery.isEmpty {
            let predicate = CNContact.predicateForContacts(matchingName: nameQuery)
            let cnContacts = try store.unifiedContacts(
                matching: predicate,
                keysToFetch: keysToFetch as [CNKeyDescriptor]
            )
            contacts.append(contentsOf: cnContacts.map(convertToTheaContact))
        }

        // Search by email
        if let emailQuery = criteria.emailQuery, !emailQuery.isEmpty {
            let predicate = CNContact.predicateForContacts(matchingEmailAddress: emailQuery)
            let cnContacts = try store.unifiedContacts(
                matching: predicate,
                keysToFetch: keysToFetch as [CNKeyDescriptor]
            )
            for cnContact in cnContacts {
                let contact = convertToTheaContact(cnContact)
                if !contacts.contains(where: { $0.id == contact.id }) {
                    contacts.append(contact)
                }
            }
        }

        // Search by phone
        if let phoneQuery = criteria.phoneQuery, !phoneQuery.isEmpty {
            let phoneNumber = CNPhoneNumber(stringValue: phoneQuery)
            let predicate = CNContact.predicateForContacts(matching: phoneNumber)
            let cnContacts = try store.unifiedContacts(
                matching: predicate,
                keysToFetch: keysToFetch as [CNKeyDescriptor]
            )
            for cnContact in cnContacts {
                let contact = convertToTheaContact(cnContact)
                if !contacts.contains(where: { $0.id == contact.id }) {
                    contacts.append(contact)
                }
            }
        }

        // Filter by birthday this month
        if criteria.hasBirthdayThisMonth {
            let currentMonth = Calendar.current.component(.month, from: Date())
            contacts = contacts.filter { contact in
                guard let birthday = contact.birthday else { return false }
                return birthday.month == currentMonth
            }
        }

        // Apply limit
        if let limit = criteria.limit, contacts.count > limit {
            contacts = Array(contacts.prefix(limit))
        }

        logger.info("Search returned \(contacts.count) contacts")
        return contacts
        #else
        throw ContactsError.unavailable
        #endif
    }

    // MARK: - Create Operations

    /// Create a new contact
    public func createContact(_ contact: TheaContact) async throws -> TheaContact {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let mutableContact = CNMutableContact()
        populateCNContact(mutableContact, from: contact)

        let saveRequest = CNSaveRequest()
        saveRequest.add(mutableContact, toContainerWithIdentifier: nil)

        try store.execute(saveRequest)

        logger.info("Created contact: \(contact.fullName)")

        // Return the contact with its new identifier
        var newContact = contact
        newContact.givenName = mutableContact.givenName
        return TheaContact(
            id: mutableContact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            middleName: contact.middleName,
            nickname: contact.nickname,
            organizationName: contact.organizationName,
            jobTitle: contact.jobTitle,
            departmentName: contact.departmentName,
            note: contact.note,
            birthday: contact.birthday,
            imageData: contact.imageData,
            phoneNumbers: contact.phoneNumbers,
            emailAddresses: contact.emailAddresses,
            postalAddresses: contact.postalAddresses,
            urlAddresses: contact.urlAddresses,
            socialProfiles: contact.socialProfiles,
            instantMessageAddresses: contact.instantMessageAddresses,
            relations: contact.relations
        )
        #else
        throw ContactsError.unavailable
        #endif
    }

    // MARK: - Update Operations

    /// Update an existing contact
    public func updateContact(_ contact: TheaContact) async throws {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let keysToFetch = contactKeysToFetch

        let cnContact = try store.unifiedContact(
            withIdentifier: contact.id,
            keysToFetch: keysToFetch as [CNKeyDescriptor]
        )

        guard let mutableContact = cnContact.mutableCopy() as? CNMutableContact else {
            throw ContactsError.updateFailed("Could not create mutable copy")
        }

        populateCNContact(mutableContact, from: contact)

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)

        try store.execute(saveRequest)

        logger.info("Updated contact: \(contact.fullName)")
        #else
        throw ContactsError.unavailable
        #endif
    }

    // MARK: - Delete Operations

    /// Delete a contact
    public func deleteContact(identifier: String) async throws {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let keysToFetch = [CNContactIdentifierKey as CNKeyDescriptor]

        let cnContact = try store.unifiedContact(
            withIdentifier: identifier,
            keysToFetch: keysToFetch
        )

        guard let mutableContact = cnContact.mutableCopy() as? CNMutableContact else {
            throw ContactsError.deleteFailed("Could not create mutable copy")
        }

        let saveRequest = CNSaveRequest()
        saveRequest.delete(mutableContact)

        try store.execute(saveRequest)

        logger.info("Deleted contact: \(identifier)")
        #else
        throw ContactsError.unavailable
        #endif
    }

    // MARK: - Group Operations

    /// Fetch all contact groups
    public func fetchGroups() async throws -> [TheaContactGroup] {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let groups = try store.groups(matching: nil)

        return groups.map { group in
            TheaContactGroup(
                id: group.identifier,
                name: group.name,
                memberCount: 0  // Would need separate query for member count
            )
        }
        #else
        throw ContactsError.unavailable
        #endif
    }

    /// Create a new group
    public func createGroup(name: String) async throws -> TheaContactGroup {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let group = CNMutableGroup()
        group.name = name

        let saveRequest = CNSaveRequest()
        saveRequest.add(group, toContainerWithIdentifier: nil)

        try store.execute(saveRequest)

        logger.info("Created group: \(name)")

        return TheaContactGroup(id: group.identifier, name: name)
        #else
        throw ContactsError.unavailable
        #endif
    }

    /// Add contact to group
    public func addContactToGroup(contactId: String, groupId: String) async throws {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let keysToFetch = [CNContactIdentifierKey as CNKeyDescriptor]
        let contact = try store.unifiedContact(
            withIdentifier: contactId,
            keysToFetch: keysToFetch
        )

        let groups = try store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [groupId]))
        guard let group = groups.first else {
            throw ContactsError.groupNotFound
        }

        let saveRequest = CNSaveRequest()
        saveRequest.addMember(contact, to: group)

        try store.execute(saveRequest)

        logger.info("Added contact \(contactId) to group \(groupId)")
        #else
        throw ContactsError.unavailable
        #endif
    }

    /// Remove contact from group
    public func removeContactFromGroup(contactId: String, groupId: String) async throws {
        #if canImport(Contacts)
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }

        let keysToFetch = [CNContactIdentifierKey as CNKeyDescriptor]
        let contact = try store.unifiedContact(
            withIdentifier: contactId,
            keysToFetch: keysToFetch
        )

        let groups = try store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [groupId]))
        guard let group = groups.first else {
            throw ContactsError.groupNotFound
        }

        let saveRequest = CNSaveRequest()
        saveRequest.removeMember(contact, from: group)

        try store.execute(saveRequest)

        logger.info("Removed contact \(contactId) from group \(groupId)")
        #else
        throw ContactsError.unavailable
        #endif
    }

    // MARK: - Helper Methods

    #if canImport(Contacts)
    private var contactKeysToFetch: [String] {
        [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactMiddleNameKey,
            CNContactNicknameKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactDepartmentNameKey,
            CNContactNoteKey,
            CNContactBirthdayKey,
            CNContactImageDataKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactPostalAddressesKey,
            CNContactUrlAddressesKey,
            CNContactSocialProfilesKey,
            CNContactInstantMessageAddressesKey,
            CNContactRelationsKey
        ]
    }

    private func convertToTheaContact(_ cnContact: CNContact) -> TheaContact {
        TheaContact(
            id: cnContact.identifier,
            givenName: cnContact.givenName,
            familyName: cnContact.familyName,
            middleName: cnContact.middleName.isEmpty ? nil : cnContact.middleName,
            nickname: cnContact.nickname.isEmpty ? nil : cnContact.nickname,
            organizationName: cnContact.organizationName.isEmpty ? nil : cnContact.organizationName,
            jobTitle: cnContact.jobTitle.isEmpty ? nil : cnContact.jobTitle,
            departmentName: cnContact.departmentName.isEmpty ? nil : cnContact.departmentName,
            note: cnContact.note.isEmpty ? nil : cnContact.note,
            birthday: cnContact.birthday,
            imageData: cnContact.imageData,
            phoneNumbers: cnContact.phoneNumbers.map { labeledValue in
                LabeledValue(
                    label: labeledValue.label,
                    value: labeledValue.value.stringValue
                )
            },
            emailAddresses: cnContact.emailAddresses.map { labeledValue in
                LabeledValue(
                    label: labeledValue.label,
                    value: labeledValue.value as String
                )
            },
            postalAddresses: cnContact.postalAddresses.map { labeledValue in
                let address = labeledValue.value
                return LabeledValue(
                    label: labeledValue.label,
                    value: PostalAddress(
                        street: address.street,
                        city: address.city,
                        state: address.state,
                        postalCode: address.postalCode,
                        country: address.country,
                        isoCountryCode: address.isoCountryCode,
                        subAdministrativeArea: address.subAdministrativeArea,
                        subLocality: address.subLocality
                    )
                )
            },
            urlAddresses: cnContact.urlAddresses.map { labeledValue in
                LabeledValue(
                    label: labeledValue.label,
                    value: labeledValue.value as String
                )
            },
            socialProfiles: cnContact.socialProfiles.map { labeledValue in
                let profile = labeledValue.value
                return LabeledValue(
                    label: labeledValue.label,
                    value: ContactSocialProfile(
                        service: profile.service,
                        username: profile.username,
                        urlString: profile.urlString,
                        userIdentifier: profile.userIdentifier
                    )
                )
            },
            instantMessageAddresses: cnContact.instantMessageAddresses.map { labeledValue in
                let im = labeledValue.value
                return LabeledValue(
                    label: labeledValue.label,
                    value: InstantMessage(
                        service: im.service,
                        username: im.username
                    )
                )
            },
            relations: cnContact.contactRelations.map { labeledValue in
                LabeledValue(
                    label: labeledValue.label,
                    value: labeledValue.value.name
                )
            }
        )
    }

    private func populateCNContact(_ cnContact: CNMutableContact, from contact: TheaContact) {
        cnContact.givenName = contact.givenName
        cnContact.familyName = contact.familyName
        cnContact.middleName = contact.middleName ?? ""
        cnContact.nickname = contact.nickname ?? ""
        cnContact.organizationName = contact.organizationName ?? ""
        cnContact.jobTitle = contact.jobTitle ?? ""
        cnContact.departmentName = contact.departmentName ?? ""
        cnContact.note = contact.note ?? ""
        cnContact.birthday = contact.birthday
        cnContact.imageData = contact.imageData

        cnContact.phoneNumbers = contact.phoneNumbers.map { labeledValue in
            CNLabeledValue(
                label: labeledValue.label,
                value: CNPhoneNumber(stringValue: labeledValue.value)
            )
        }

        cnContact.emailAddresses = contact.emailAddresses.map { labeledValue in
            CNLabeledValue(
                label: labeledValue.label,
                value: labeledValue.value as NSString
            )
        }

        cnContact.postalAddresses = contact.postalAddresses.map { labeledValue in
            let address = CNMutablePostalAddress()
            address.street = labeledValue.value.street
            address.city = labeledValue.value.city
            address.state = labeledValue.value.state
            address.postalCode = labeledValue.value.postalCode
            address.country = labeledValue.value.country
            address.isoCountryCode = labeledValue.value.isoCountryCode ?? ""
            address.subAdministrativeArea = labeledValue.value.subAdministrativeArea ?? ""
            address.subLocality = labeledValue.value.subLocality ?? ""
            return CNLabeledValue(label: labeledValue.label, value: address)
        }

        cnContact.urlAddresses = contact.urlAddresses.map { labeledValue in
            CNLabeledValue(
                label: labeledValue.label,
                value: labeledValue.value as NSString
            )
        }

        cnContact.socialProfiles = contact.socialProfiles.map { labeledValue in
            let profile = CNSocialProfile(
                urlString: labeledValue.value.urlString,
                username: labeledValue.value.username,
                userIdentifier: labeledValue.value.userIdentifier,
                service: labeledValue.value.service
            )
            return CNLabeledValue(label: labeledValue.label, value: profile)
        }

        cnContact.instantMessageAddresses = contact.instantMessageAddresses.map { labeledValue in
            let im = CNInstantMessageAddress(
                username: labeledValue.value.username,
                service: labeledValue.value.service
            )
            return CNLabeledValue(label: labeledValue.label, value: im)
        }

        cnContact.contactRelations = contact.relations.map { labeledValue in
            CNLabeledValue(
                label: labeledValue.label,
                value: CNContactRelation(name: labeledValue.value)
            )
        }
    }
    #endif
}

// MARK: - Supporting Types

/// Authorization status for contacts
public enum ContactAuthorizationStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case limited
    case unavailable
}

/// Errors for contacts operations
public enum ContactsError: LocalizedError {
    case notAuthorized
    case unavailable
    case contactNotFound
    case groupNotFound
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Contact access not authorized"
        case .unavailable:
            "Contacts framework not available on this platform"
        case .contactNotFound:
            "Contact not found"
        case .groupNotFound:
            "Contact group not found"
        case .createFailed(let reason):
            "Failed to create contact: \(reason)"
        case .updateFailed(let reason):
            "Failed to update contact: \(reason)"
        case .deleteFailed(let reason):
            "Failed to delete contact: \(reason)"
        }
    }
}
