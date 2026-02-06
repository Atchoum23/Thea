import Combine
import Foundation
#if canImport(HealthKit)
    import HealthKit
#endif
#if os(iOS)
    import UIKit
#endif

/// Health data synchronization service for cross-device sync and cloud backup
public actor HealthDataSync {
    public static let shared = HealthDataSync()

    private var syncTasks: [UUID: Task<Void, Never>] = [:]
    private var lastSyncDate: Date?
    private let syncInterval: TimeInterval = 3600 // 1 hour

    public enum SyncError: Error, Sendable, LocalizedError {
        case healthKitUnavailable
        case noDataToSync
        case syncInProgress
        case cloudStorageUnavailable
        case authorizationDenied

        public var errorDescription: String? {
            switch self {
            case .healthKitUnavailable:
                "HealthKit is not available on this device"
            case .noDataToSync:
                "No health data available to synchronize"
            case .syncInProgress:
                "A sync operation is already in progress"
            case .cloudStorageUnavailable:
                "Cloud storage is not available"
            case .authorizationDenied:
                "HealthKit authorization was denied"
            }
        }
    }

    public enum SyncStatus: Sendable {
        case idle
        case syncing
        case completed
        case failed(Error)

        public var isActive: Bool {
            if case .syncing = self { return true }
            return false
        }
    }

    private init() {}

    // MARK: - Public API

    /// Syncs health data to cloud storage
    public func syncToCloud() async throws {
        #if canImport(HealthKit)
            guard HKHealthStore.isHealthDataAvailable() else {
                throw SyncError.healthKitUnavailable
            }

            // Check if sync is already in progress
            guard syncTasks.isEmpty else {
                throw SyncError.syncInProgress
            }

            let syncTask = Task {
                do {
                    try await performCloudSync()
                    lastSyncDate = Date()
                } catch {
                    print("Cloud sync failed: \(error.localizedDescription)")
                }
            }

            let taskID = UUID()
            syncTasks[taskID] = syncTask

            await syncTask.value

            syncTasks.removeValue(forKey: taskID)
        #else
            throw SyncError.healthKitUnavailable
        #endif
    }

    /// Syncs health data from cloud storage
    public func syncFromCloud() async throws {
        #if canImport(HealthKit)
            guard HKHealthStore.isHealthDataAvailable() else {
                throw SyncError.healthKitUnavailable
            }

            try await performCloudFetch()
        #else
            throw SyncError.healthKitUnavailable
        #endif
    }

    /// Checks if sync is needed based on last sync time
    public func shouldSync() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) >= syncInterval
    }

    /// Cancels all active sync operations
    public func cancelSync() {
        for (_, task) in syncTasks {
            task.cancel()
        }
        syncTasks.removeAll()
    }

    /// Returns the last successful sync date
    public func getLastSyncDate() -> Date? {
        lastSyncDate
    }

    // MARK: - Private Methods

    private func performCloudSync() async throws {
        #if canImport(HealthKit)
            // 1. Fetch recent health data
            let healthData = try await fetchRecentHealthData()

            guard !healthData.isEmpty else {
                throw SyncError.noDataToSync
            }

            // 2. Prepare data for upload
            let syncPackage = try prepareSyncPackage(healthData)

            // 3. Upload to cloud storage
            try await uploadToCloud(syncPackage)

            // 4. Verify upload
            try await verifyCloudData()
        #endif
    }

    private func performCloudFetch() async throws {
        #if canImport(HealthKit)
            // 1. Fetch data from cloud
            let cloudData = try await fetchFromCloud()

            // 2. Validate data
            guard validateCloudData(cloudData) else {
                throw SyncError.noDataToSync
            }

            // 3. Import to HealthKit
            try await importToHealthKit(cloudData)
        #endif
    }

    #if canImport(HealthKit)
        private func fetchRecentHealthData() async throws -> [HealthDataRecord] {
            let healthStore = HKHealthStore()

            // Fetch data from last sync or last 24 hours
            let startDate = lastSyncDate ?? Date().daysAgo(1)
            let endDate = Date()

            var records: [HealthDataRecord] = []

            // Fetch sleep data
            if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                let sleepData = try await fetchQuantityData(healthStore, type: sleepType, start: startDate, end: endDate)
                records.append(contentsOf: sleepData)
            }

            // Fetch heart rate data
            if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
                let heartRateData = try await fetchQuantityData(healthStore, type: heartRateType, start: startDate, end: endDate)
                records.append(contentsOf: heartRateData)
            }

            // Fetch step count data
            if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
                let stepsData = try await fetchQuantityData(healthStore, type: stepsType, start: startDate, end: endDate)
                records.append(contentsOf: stepsData)
            }

            // Fetch blood pressure data
            if let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
               let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)
            {
                let bpData = try await fetchBloodPressureData(healthStore, systolic: systolicType, diastolic: diastolicType, start: startDate, end: endDate)
                records.append(contentsOf: bpData)
            }

            return records
        }

        private func fetchQuantityData(
            _: HKHealthStore,
            type _: HKObjectType,
            start _: Date,
            end _: Date
        ) async throws -> [HealthDataRecord] {
            // Would implement actual HealthKit query
            // Mock implementation for now
            []
        }

        private func fetchBloodPressureData(
            _: HKHealthStore,
            systolic _: HKQuantityType,
            diastolic _: HKQuantityType,
            start _: Date,
            end _: Date
        ) async throws -> [HealthDataRecord] {
            // Would implement actual HealthKit correlation query
            []
        }
    #endif

    private func prepareSyncPackage(_ data: [HealthDataRecord]) throws -> SyncPackage {
        SyncPackage(
            version: "1.0",
            timestamp: Date(),
            deviceIdentifier: getDeviceIdentifier(),
            records: data
        )
    }

    private func uploadToCloud(_: SyncPackage) async throws {
        // Would implement actual cloud upload (iCloud, CloudKit, etc.)
        // Mock implementation
        try await Task.sleep(for: .milliseconds(500))
    }

    private func verifyCloudData() async throws {
        // Would verify uploaded data integrity
        try await Task.sleep(for: .milliseconds(200))
    }

    private func fetchFromCloud() async throws -> SyncPackage {
        // Would implement actual cloud fetch
        try await Task.sleep(for: .milliseconds(500))

        return SyncPackage(
            version: "1.0",
            timestamp: Date(),
            deviceIdentifier: getDeviceIdentifier(),
            records: []
        )
    }

    private func validateCloudData(_ package: SyncPackage) -> Bool {
        // Validate package version and data integrity
        package.version == "1.0" && !package.records.isEmpty
    }

    #if canImport(HealthKit)
        private func importToHealthKit(_ package: SyncPackage) async throws {
            let healthStore = HKHealthStore()

            for record in package.records {
                try await saveRecordToHealthKit(healthStore, record: record)
            }
        }

        private func saveRecordToHealthKit(_: HKHealthStore, record _: HealthDataRecord) async throws {
            // Would implement actual HealthKit save
            // Mock implementation
            try await Task.sleep(for: .milliseconds(50))
        }
    #endif

    private func getDeviceIdentifier() -> String {
        #if os(iOS)
            // UIDevice.current is MainActor-isolated, so we need to access it on MainActor
            return MainActor.assumeIsolated {
                UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
            }
        #elseif os(macOS)
            // macOS device identifier
            var size = 0
            sysctlbyname("kern.uuid", nil, &size, nil, 0)
            var uuid = [UInt8](repeating: 0, count: size)
            sysctlbyname("kern.uuid", &uuid, &size, nil, 0)
            // Truncate null termination and decode as UTF-8
            let truncatedUUID = uuid.prefix { $0 != 0 }
            return String(decoding: truncatedUUID, as: UTF8.self)
        #else
            return "unknown-device"
        #endif
    }
}

// MARK: - Data Models

public struct HealthDataRecord: Sendable, Codable {
    public let id: UUID
    public var dataType: HealthDataType
    public var value: Double
    public var unit: String
    public var timestamp: Date
    public var sourceDevice: String

    public init(
        id: UUID = UUID(),
        dataType: HealthDataType,
        value: Double,
        unit: String,
        timestamp: Date,
        sourceDevice: String
    ) {
        self.id = id
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.sourceDevice = sourceDevice
    }
}

public enum HealthDataType: String, Sendable, Codable {
    case sleepDuration
    case sleepQuality
    case heartRate
    case restingHeartRate
    case heartRateVariability
    case steps
    case distance
    case activeCalories
    case bloodPressureSystolic
    case bloodPressureDiastolic
    case bloodGlucose
    case bodyWeight
    case bodyMassIndex
    case bodyFatPercentage
    case oxygenSaturation
}

public struct SyncPackage: Sendable, Codable {
    public var version: String
    public var timestamp: Date
    public var deviceIdentifier: String
    public var records: [HealthDataRecord]

    public init(version: String, timestamp: Date, deviceIdentifier: String, records: [HealthDataRecord]) {
        self.version = version
        self.timestamp = timestamp
        self.deviceIdentifier = deviceIdentifier
        self.records = records
    }
}

// MARK: - Sync Observer Protocol

public protocol HealthDataSyncObserver: AnyObject, Sendable {
    func syncDidStart()
    func syncDidComplete()
    func syncDidFail(error: Error)
    func syncProgressDidUpdate(progress: Double)
}

// MARK: - Sync Coordinator

@MainActor
public final class HealthDataSyncCoordinator: ObservableObject {
    @Published public var syncStatus: HealthDataSync.SyncStatus = .idle
    @Published public var lastSyncDate: Date?
    @Published public var isSyncing: Bool = false

    private let syncService = HealthDataSync.shared

    public init() {}

    public func startSync() async {
        isSyncing = true
        syncStatus = .syncing

        do {
            try await syncService.syncToCloud()
            lastSyncDate = Date()
            syncStatus = .completed
        } catch {
            syncStatus = .failed(error)
        }

        isSyncing = false
    }

    public func cancelSync() async {
        await syncService.cancelSync()
        isSyncing = false
        syncStatus = .idle
    }

    public func shouldSync() async -> Bool {
        await syncService.shouldSync()
    }
}
