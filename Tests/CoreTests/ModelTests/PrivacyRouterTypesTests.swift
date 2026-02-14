// PrivacyRouterTypesTests.swift
// Tests for PrivacyPreservingAIRouter types

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum DataSensitivityLevel: Int, Sendable, Comparable {
    case public_ = 0
    case contextual = 1
    case personal = 2
    case sensitive = 3
    case critical = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var requiresLocalProcessing: Bool {
        self >= .personal
    }

    var canBeAnonymized: Bool {
        self <= .sensitive
    }

    var description: String {
        switch self {
        case .public_: "Public"
        case .contextual: "Contextual"
        case .personal: "Personal"
        case .sensitive: "Sensitive"
        case .critical: "Critical"
        }
    }
}

private enum PrivateDataType: String, Sendable, CaseIterable {
    case fullName = "full_name"
    case email = "email"
    case phoneNumber = "phone_number"
    case address = "address"
    case birthDate = "birth_date"
    case bankAccount = "bank_account"
    case creditCard = "credit_card"
    case income = "income"
    case transactions = "transactions"
    case investments = "investments"
    case medicalRecords = "medical_records"
    case medications = "medications"
    case mentalHealth = "mental_health"
    case biometrics = "biometrics"
    case emailContent = "email_content"
    case messageContent = "message_content"
    case callTranscript = "call_transcript"
    case contactList = "contact_list"
    case preciseLocation = "precise_location"
    case locationHistory = "location_history"
    case homeAddress = "home_address"
    case workAddress = "work_address"
    case password = "password"
    case ssn = "ssn"
    case governmentId = "government_id"
    case apiKey = "api_key"
    case browsingHistory = "browsing_history"
    case appUsage = "app_usage"
    case searchHistory = "search_history"
    case purchaseHistory = "purchase_history"

    var defaultSensitivity: DataSensitivityLevel {
        switch self {
        case .password, .ssn, .governmentId, .apiKey:
            return .critical
        case .bankAccount, .creditCard, .income,
             .transactions, .investments,
             .medicalRecords, .medications,
             .mentalHealth, .biometrics,
             .callTranscript:
            return .sensitive
        case .fullName, .email, .phoneNumber,
             .address, .birthDate,
             .emailContent, .messageContent,
             .contactList,
             .preciseLocation, .locationHistory,
             .homeAddress, .workAddress,
             .browsingHistory, .searchHistory,
             .purchaseHistory:
            return .personal
        case .appUsage:
            return .contextual
        }
    }
}

private enum AnonymizationStrategy: String, Sendable {
    case hash, pseudonymize, generalize, suppress
    case aggregate, temporalShift, spatialBlur, categorize
}

private enum ProcessingRoute: String, Sendable {
    case localOnly = "local"
    case localPreferred = "local_pref"
    case remoteAnonymized = "remote_anon"
    case remoteAllowed = "remote"
}

// MARK: - DataSensitivityLevel Tests

final class DataSensitivityLevelTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(DataSensitivityLevel.public_.rawValue, 0)
        XCTAssertEqual(DataSensitivityLevel.contextual.rawValue, 1)
        XCTAssertEqual(DataSensitivityLevel.personal.rawValue, 2)
        XCTAssertEqual(DataSensitivityLevel.sensitive.rawValue, 3)
        XCTAssertEqual(DataSensitivityLevel.critical.rawValue, 4)
    }

    func testComparable() {
        XCTAssertTrue(DataSensitivityLevel.public_ < .contextual)
        XCTAssertTrue(DataSensitivityLevel.contextual < .personal)
        XCTAssertTrue(DataSensitivityLevel.personal < .sensitive)
        XCTAssertTrue(DataSensitivityLevel.sensitive < .critical)
        XCTAssertFalse(DataSensitivityLevel.critical < .public_)
    }

    func testRequiresLocalProcessing() {
        XCTAssertFalse(DataSensitivityLevel.public_.requiresLocalProcessing)
        XCTAssertFalse(
            DataSensitivityLevel.contextual.requiresLocalProcessing
        )
        XCTAssertTrue(DataSensitivityLevel.personal.requiresLocalProcessing)
        XCTAssertTrue(DataSensitivityLevel.sensitive.requiresLocalProcessing)
        XCTAssertTrue(DataSensitivityLevel.critical.requiresLocalProcessing)
    }

    func testCanBeAnonymized() {
        XCTAssertTrue(DataSensitivityLevel.public_.canBeAnonymized)
        XCTAssertTrue(DataSensitivityLevel.contextual.canBeAnonymized)
        XCTAssertTrue(DataSensitivityLevel.personal.canBeAnonymized)
        XCTAssertTrue(DataSensitivityLevel.sensitive.canBeAnonymized)
        XCTAssertFalse(DataSensitivityLevel.critical.canBeAnonymized)
    }

    func testDescription() {
        XCTAssertEqual(DataSensitivityLevel.public_.description, "Public")
        XCTAssertEqual(
            DataSensitivityLevel.contextual.description, "Contextual"
        )
        XCTAssertEqual(DataSensitivityLevel.personal.description, "Personal")
        XCTAssertEqual(
            DataSensitivityLevel.sensitive.description, "Sensitive"
        )
        XCTAssertEqual(DataSensitivityLevel.critical.description, "Critical")
    }

    func testCriticalNeverAnonymized() {
        // Critical data should require local AND not be anonymizable
        let critical = DataSensitivityLevel.critical
        XCTAssertTrue(critical.requiresLocalProcessing)
        XCTAssertFalse(critical.canBeAnonymized)
    }

    func testPublicNeverLocal() {
        let pub = DataSensitivityLevel.public_
        XCTAssertFalse(pub.requiresLocalProcessing)
        XCTAssertTrue(pub.canBeAnonymized)
    }
}

// MARK: - PrivateDataType Tests

final class PrivateDataTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PrivateDataType.allCases.count, 30)
    }

    func testCriticalTypes() {
        let criticalTypes: [PrivateDataType] = [
            .password, .ssn, .governmentId, .apiKey
        ]
        for type in criticalTypes {
            XCTAssertEqual(
                type.defaultSensitivity, .critical,
                "\(type.rawValue) should be critical"
            )
        }
    }

    func testSensitiveTypes() {
        let sensitiveTypes: [PrivateDataType] = [
            .bankAccount, .creditCard, .income,
            .transactions, .investments,
            .medicalRecords, .medications,
            .mentalHealth, .biometrics, .callTranscript
        ]
        for type in sensitiveTypes {
            XCTAssertEqual(
                type.defaultSensitivity, .sensitive,
                "\(type.rawValue) should be sensitive"
            )
        }
    }

    func testPersonalTypes() {
        let personalTypes: [PrivateDataType] = [
            .fullName, .email, .phoneNumber, .address,
            .birthDate, .emailContent, .messageContent,
            .contactList, .preciseLocation,
            .locationHistory, .homeAddress, .workAddress,
            .browsingHistory, .searchHistory, .purchaseHistory
        ]
        for type in personalTypes {
            XCTAssertEqual(
                type.defaultSensitivity, .personal,
                "\(type.rawValue) should be personal"
            )
        }
    }

    func testContextualTypes() {
        XCTAssertEqual(
            PrivateDataType.appUsage.defaultSensitivity,
            .contextual
        )
    }

    func testNoPublicDataTypes() {
        // No data type defaults to public — privacy by design
        for type in PrivateDataType.allCases {
            XCTAssertNotEqual(
                type.defaultSensitivity, .public_,
                "\(type.rawValue) should not be public"
            )
        }
    }

    func testAllRawValuesUnique() {
        let rawValues = PrivateDataType.allCases.map(\.rawValue)
        XCTAssertEqual(
            rawValues.count, Set(rawValues).count,
            "All raw values must be unique"
        )
    }

    func testCriticalAlwaysRequiresLocal() {
        for type in PrivateDataType.allCases {
            if type.defaultSensitivity == .critical {
                XCTAssertTrue(
                    type.defaultSensitivity.requiresLocalProcessing,
                    "\(type.rawValue) critical data must require local"
                )
            }
        }
    }
}

// MARK: - AnonymizationStrategy Tests

final class AnonymizationStrategyTests: XCTestCase {

    func testAllStrategies() {
        let strategies: [AnonymizationStrategy] = [
            .hash, .pseudonymize, .generalize, .suppress,
            .aggregate, .temporalShift, .spatialBlur, .categorize
        ]
        XCTAssertEqual(strategies.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(AnonymizationStrategy.hash.rawValue, "hash")
        XCTAssertEqual(
            AnonymizationStrategy.pseudonymize.rawValue, "pseudonymize"
        )
        XCTAssertEqual(
            AnonymizationStrategy.spatialBlur.rawValue, "spatialBlur"
        )
    }
}

// MARK: - ProcessingRoute Tests

final class ProcessingRouteTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(ProcessingRoute.localOnly.rawValue, "local")
        XCTAssertEqual(
            ProcessingRoute.localPreferred.rawValue, "local_pref"
        )
        XCTAssertEqual(
            ProcessingRoute.remoteAnonymized.rawValue, "remote_anon"
        )
        XCTAssertEqual(ProcessingRoute.remoteAllowed.rawValue, "remote")
    }
}
