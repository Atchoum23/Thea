//
//  CallDirectoryHandler.swift
//  Thea CallKit Extension
//
//  Created by Thea
//  Caller ID and call blocking integration
//

import CallKit
import Foundation
import os.log

/// Call Directory extension for Caller ID and call blocking
class CallDirectoryHandler: CXCallDirectoryProvider {
    private let logger = Logger(subsystem: "app.thea.callkit", category: "CallDirectory")

    // MARK: - Lifecycle

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Check if incremental loading is supported
        if context.isIncremental {
            addOrRemoveIncrementalBlockingPhoneNumbers(to: context)
            addOrRemoveIncrementalIdentificationPhoneNumbers(to: context)
        } else {
            addAllBlockingPhoneNumbers(to: context)
            addAllIdentificationPhoneNumbers(to: context)
        }

        context.completeRequest()
    }

    // MARK: - Blocking

    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Load blocked numbers from shared storage
        let blockedNumbers = loadBlockedNumbers()

        // Numbers MUST be sorted in ascending order
        let sortedNumbers = blockedNumbers.sorted()

        for number in sortedNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        logger.info("Added \(sortedNumbers.count) blocked numbers")
    }

    private func addOrRemoveIncrementalBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Load incremental changes
        let changes = loadBlockingChanges()

        // Remove numbers first (must be in ascending order)
        let numbersToRemove = changes.removed.sorted()
        for number in numbersToRemove {
            context.removeBlockingEntry(withPhoneNumber: number)
        }

        // Then add numbers (must be in ascending order)
        let numbersToAdd = changes.added.sorted()
        for number in numbersToAdd {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        // Clear incremental changes
        clearBlockingChanges()

        logger.info("Incremental blocking update: +\(numbersToAdd.count), -\(numbersToRemove.count)")
    }

    // MARK: - Identification

    private func addAllIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Load caller ID entries from shared storage
        let callerIDEntries = loadCallerIDEntries()

        // Entries MUST be sorted by phone number in ascending order
        let sortedEntries = callerIDEntries.sorted { $0.phoneNumber < $1.phoneNumber }

        for entry in sortedEntries {
            context.addIdentificationEntry(
                withNextSequentialPhoneNumber: entry.phoneNumber,
                label: entry.label
            )
        }

        logger.info("Added \(sortedEntries.count) caller ID entries")
    }

    private func addOrRemoveIncrementalIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Load incremental changes
        let changes = loadIdentificationChanges()

        // Remove entries first (must be in ascending order)
        let numbersToRemove = changes.removed.sorted()
        for number in numbersToRemove {
            context.removeIdentificationEntry(withPhoneNumber: number)
        }

        // Then add entries (must be in ascending order)
        let entriesToAdd = changes.added.sorted { $0.phoneNumber < $1.phoneNumber }
        for entry in entriesToAdd {
            context.addIdentificationEntry(
                withNextSequentialPhoneNumber: entry.phoneNumber,
                label: entry.label
            )
        }

        // Clear incremental changes
        clearIdentificationChanges()

        logger.info("Incremental ID update: +\(entriesToAdd.count), -\(numbersToRemove.count)")
    }

    // MARK: - Data Loading

    private func loadBlockedNumbers() -> [CXCallDirectoryPhoneNumber] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return [] }

        let dataURL = containerURL.appendingPathComponent("blocked_numbers.json")

        guard let data = try? Data(contentsOf: dataURL),
              let numbers = try? JSONDecoder().decode([CXCallDirectoryPhoneNumber].self, from: data)
        else {
            return []
        }

        return numbers
    }

    private func loadBlockingChanges() -> (added: [CXCallDirectoryPhoneNumber], removed: [CXCallDirectoryPhoneNumber]) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return ([], []) }

        let addedURL = containerURL.appendingPathComponent("blocked_numbers_added.json")
        let removedURL = containerURL.appendingPathComponent("blocked_numbers_removed.json")

        let added = (try? JSONDecoder().decode([CXCallDirectoryPhoneNumber].self, from: Data(contentsOf: addedURL))) ?? []
        let removed = (try? JSONDecoder().decode([CXCallDirectoryPhoneNumber].self, from: Data(contentsOf: removedURL))) ?? []

        return (added, removed)
    }

    private func clearBlockingChanges() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return }

        let addedURL = containerURL.appendingPathComponent("blocked_numbers_added.json")
        let removedURL = containerURL.appendingPathComponent("blocked_numbers_removed.json")

        try? FileManager.default.removeItem(at: addedURL)
        try? FileManager.default.removeItem(at: removedURL)
    }

    private func loadCallerIDEntries() -> [CallerIDEntry] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return [] }

        let dataURL = containerURL.appendingPathComponent("caller_id_entries.json")

        guard let data = try? Data(contentsOf: dataURL),
              let entries = try? JSONDecoder().decode([CallerIDEntry].self, from: data)
        else {
            return []
        }

        return entries
    }

    private func loadIdentificationChanges() -> (added: [CallerIDEntry], removed: [CXCallDirectoryPhoneNumber]) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return ([], []) }

        let addedURL = containerURL.appendingPathComponent("caller_id_added.json")
        let removedURL = containerURL.appendingPathComponent("caller_id_removed.json")

        let added = (try? JSONDecoder().decode([CallerIDEntry].self, from: Data(contentsOf: addedURL))) ?? []
        let removed = (try? JSONDecoder().decode([CXCallDirectoryPhoneNumber].self, from: Data(contentsOf: removedURL))) ?? []

        return (added, removed)
    }

    private func clearIdentificationChanges() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return }

        let addedURL = containerURL.appendingPathComponent("caller_id_added.json")
        let removedURL = containerURL.appendingPathComponent("caller_id_removed.json")

        try? FileManager.default.removeItem(at: addedURL)
        try? FileManager.default.removeItem(at: removedURL)
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for _: CXCallDirectoryExtensionContext, withError error: Error) {
        logger.error("Call Directory request failed: \(error)")

        // Handle specific errors
        if let cdError = error as? CXErrorCodeCallDirectoryManagerError {
            switch cdError.code {
            case .entriesOutOfOrder:
                logger.error("Entries were out of order - data needs to be sorted")
            case .duplicateEntries:
                logger.error("Duplicate entries found - need to deduplicate")
            case .maximumEntriesExceeded:
                logger.error("Too many entries - need to reduce")
            case .extensionDisabled:
                logger.error("Extension is disabled by user")
            default:
                logger.error("Unknown error: \(cdError.code.rawValue)")
            }
        }
    }
}

// MARK: - Supporting Types

struct CallerIDEntry: Codable {
    let phoneNumber: CXCallDirectoryPhoneNumber
    let label: String
}
