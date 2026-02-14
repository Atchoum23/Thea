import CloudKit
import Combine
import Foundation
import OSLog
#if canImport(HealthKit)
    import HealthKit
#endif
#if os(iOS)
    import UIKit
#endif

private let syncLogger = Logger(subsystem: "com.thea.app", category: "HealthDataSync")

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
            _ healthStore: HKHealthStore,
            type: HKObjectType,
            start: Date,
            end: Date
        ) async throws -> [HealthDataRecord] {
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let deviceId = getDeviceIdentifier()

            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type as! HKSampleType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error {
                        syncLogger.error("HealthKit query failed for \(type.identifier): \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }

                    var records: [HealthDataRecord] = []
                    for sample in samples ?? [] {
                        if let quantitySample = sample as? HKQuantitySample {
                            let (dataType, unit) = Self.mapQuantityType(quantitySample.quantityType)
                            let value = quantitySample.quantity.doubleValue(for: unit)
                            records.append(HealthDataRecord(
                                dataType: dataType,
                                value: value,
                                unit: unit.unitString,
                                timestamp: quantitySample.startDate,
                                sourceDevice: deviceId
                            ))
                        } else if let categorySample = sample as? HKCategorySample {
                            // Sleep analysis: value is duration in seconds
                            let duration = categorySample.endDate.timeIntervalSince(categorySample.startDate)
                            records.append(HealthDataRecord(
                                dataType: .sleepDuration,
                                value: duration / 3600.0,
                                unit: "hr",
                                timestamp: categorySample.startDate,
                                sourceDevice: deviceId
                            ))
                        }
                    }
                    continuation.resume(returning: records)
                }
                healthStore.execute(query)
            }
        }

        private static func mapQuantityType(_ type: HKQuantityType) -> (HealthDataType, HKUnit) {
            switch type.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                return (.heartRate, HKUnit.count().unitDivided(by: .minute()))
            case HKQuantityTypeIdentifier.stepCount.rawValue:
                return (.steps, .count())
            case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
                return (.distance, .meter())
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                return (.activeCalories, .kilocalorie())
            case HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue:
                return (.bloodPressureSystolic, .millimeterOfMercury())
            case HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue:
                return (.bloodPressureDiastolic, .millimeterOfMercury())
            case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
                return (.oxygenSaturation, .percent())
            case HKQuantityTypeIdentifier.bodyMass.rawValue:
                return (.bodyWeight, .gramUnit(with: .kilo))
            case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
                return (.bodyFatPercentage, .percent())
            case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
                return (.heartRateVariability, .secondUnit(with: .milli))
            default:
                return (.steps, .count())
            }
        }

        private func fetchBloodPressureData(
            _ healthStore: HKHealthStore,
            systolic systolicType: HKQuantityType,
            diastolic diastolicType: HKQuantityType,
            start: Date,
            end: Date
        ) async throws -> [HealthDataRecord] {
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let deviceId = getDeviceIdentifier()

            // Fetch systolic samples
            let systolicRecords: [HealthDataRecord] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: systolicType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let records = (samples as? [HKQuantitySample] ?? []).map { sample in
                        HealthDataRecord(
                            dataType: .bloodPressureSystolic,
                            value: sample.quantity.doubleValue(for: .millimeterOfMercury()),
                            unit: "mmHg",
                            timestamp: sample.startDate,
                            sourceDevice: deviceId
                        )
                    }
                    continuation.resume(returning: records)
                }
                healthStore.execute(query)
            }

            // Fetch diastolic samples
            let diastolicRecords: [HealthDataRecord] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: diastolicType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let records = (samples as? [HKQuantitySample] ?? []).map { sample in
                        HealthDataRecord(
                            dataType: .bloodPressureDiastolic,
                            value: sample.quantity.doubleValue(for: .millimeterOfMercury()),
                            unit: "mmHg",
                            timestamp: sample.startDate,
                            sourceDevice: deviceId
                        )
                    }
                    continuation.resume(returning: records)
                }
                healthStore.execute(query)
            }

            return systolicRecords + diastolicRecords
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

    private static let cloudKitRecordType = "HealthSyncPackage"
    private static let cloudKitZoneName = "TheaZone"

    private func getContainer() -> CKContainer {
        let id = "iCloud.app.theathe"
        if let containers = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
           containers.contains(id)
        {
            return CKContainer(identifier: id)
        }
        return CKContainer.default()
    }

    private func uploadToCloud(_ package: SyncPackage) async throws {
        let container = getContainer()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: Self.cloudKitZoneName, ownerName: CKCurrentUserDefaultName)

        // Ensure zone exists
        do {
            _ = try await database.save(CKRecordZone(zoneID: zoneID))
        } catch let error as CKError where error.code == .serverRecordChanged || error.code == .zoneNotFound {
            syncLogger.debug("Zone already exists or transient error, continuing upload")
        } catch {
            // Zone may already exist, which is fine
            syncLogger.debug("Zone save: \(error.localizedDescription)")
        }

        // Encode records as JSON data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let recordsData = try encoder.encode(package.records)

        let recordID = CKRecord.ID(
            recordName: "health-sync-\(package.deviceIdentifier)-\(Int(package.timestamp.timeIntervalSince1970))",
            zoneID: zoneID
        )
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: recordID)
        record["version"] = package.version as CKRecordValue
        record["timestamp"] = package.timestamp as CKRecordValue
        record["deviceIdentifier"] = package.deviceIdentifier as CKRecordValue
        record["recordCount"] = package.records.count as CKRecordValue
        record["recordsData"] = recordsData as CKRecordValue

        do {
            _ = try await database.save(record)
            syncLogger.info("Uploaded \(package.records.count) health records to CloudKit")
        } catch {
            syncLogger.error("CloudKit upload failed: \(error.localizedDescription)")
            throw SyncError.cloudStorageUnavailable
        }
    }

    private func verifyCloudData() async throws {
        // Query the most recent record to verify it was saved
        let container = getContainer()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: Self.cloudKitZoneName, ownerName: CKCurrentUserDefaultName)

        let predicate = NSPredicate(format: "deviceIdentifier == %@", getDeviceIdentifier())
        let query = CKQuery(recordType: Self.cloudKitRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID, resultsLimit: 1)
            guard !results.isEmpty else {
                syncLogger.warning("Verification failed: no records found after upload")
                return
            }
            syncLogger.info("Cloud data verified successfully")
        } catch {
            syncLogger.warning("Cloud verification query failed: \(error.localizedDescription)")
        }
    }

    private func fetchFromCloud() async throws -> SyncPackage {
        let container = getContainer()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: Self.cloudKitZoneName, ownerName: CKCurrentUserDefaultName)

        // Fetch the most recent sync package from any device
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: Self.cloudKitRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID, resultsLimit: 5)

            var allRecords: [HealthDataRecord] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for (_, result) in results {
                guard let record = try? result.get(),
                      let recordsData = record["recordsData"] as? Data else { continue }
                let records = (try? decoder.decode([HealthDataRecord].self, from: recordsData)) ?? []
                allRecords.append(contentsOf: records)
            }

            syncLogger.info("Fetched \(allRecords.count) health records from CloudKit")
            return SyncPackage(
                version: "1.0",
                timestamp: Date(),
                deviceIdentifier: getDeviceIdentifier(),
                records: allRecords
            )
        } catch {
            syncLogger.error("CloudKit fetch failed: \(error.localizedDescription)")
            throw SyncError.cloudStorageUnavailable
        }
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

        private func saveRecordToHealthKit(_ healthStore: HKHealthStore, record: HealthDataRecord) async throws {
            guard let (quantityType, unit) = Self.healthKitMapping(for: record.dataType) else {
                syncLogger.debug("Skipping unsupported data type for HealthKit save: \(record.dataType.rawValue)")
                return
            }

            let quantity = HKQuantity(unit: unit, doubleValue: record.value)
            let sample = HKQuantitySample(
                type: quantityType,
                quantity: quantity,
                start: record.timestamp,
                end: record.timestamp
            )

            try await healthStore.save(sample)
        }

        private static func healthKitMapping(for dataType: HealthDataType) -> (HKQuantityType, HKUnit)? {
            switch dataType {
            case .heartRate:
                return (HKQuantityType(.heartRate), HKUnit.count().unitDivided(by: .minute()))
            case .steps:
                return (HKQuantityType(.stepCount), .count())
            case .distance:
                return (HKQuantityType(.distanceWalkingRunning), .meter())
            case .activeCalories:
                return (HKQuantityType(.activeEnergyBurned), .kilocalorie())
            case .bloodPressureSystolic:
                return (HKQuantityType(.bloodPressureSystolic), .millimeterOfMercury())
            case .bloodPressureDiastolic:
                return (HKQuantityType(.bloodPressureDiastolic), .millimeterOfMercury())
            case .oxygenSaturation:
                return (HKQuantityType(.oxygenSaturation), .percent())
            case .bodyWeight:
                return (HKQuantityType(.bodyMass), .gramUnit(with: .kilo))
            case .bodyFatPercentage:
                return (HKQuantityType(.bodyFatPercentage), .percent())
            case .heartRateVariability:
                return (HKQuantityType(.heartRateVariabilitySDNN), .secondUnit(with: .milli))
            case .restingHeartRate:
                return (HKQuantityType(.restingHeartRate), HKUnit.count().unitDivided(by: .minute()))
            case .sleepDuration, .sleepQuality, .bloodGlucose, .bodyMassIndex:
                return nil
            }
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
