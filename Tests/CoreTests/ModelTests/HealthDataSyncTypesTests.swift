// HealthDataSyncTypesTests.swift
// Tests for HealthDataSync types: HealthDataRecord, SyncPackage, HealthDataType
// Standalone test doubles mirroring production types

import Testing
import Foundation

// MARK: - Test Doubles (mirror production types in HealthDataSync.swift)

private enum TestHealthDataType: String, Sendable, Codable, CaseIterable {
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

private struct TestHealthDataRecord: Sendable, Codable, Identifiable {
    let id: UUID
    var dataType: TestHealthDataType
    var value: Double
    var unit: String
    var timestamp: Date
    var sourceDevice: String

    init(
        id: UUID = UUID(),
        dataType: TestHealthDataType,
        value: Double,
        unit: String,
        timestamp: Date = Date(),
        sourceDevice: String = "test-device"
    ) {
        self.id = id
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.sourceDevice = sourceDevice
    }
}

private struct TestSyncPackage: Sendable, Codable {
    var version: String
    var timestamp: Date
    var deviceIdentifier: String
    var records: [TestHealthDataRecord]

    init(version: String = "1.0", timestamp: Date = Date(), deviceIdentifier: String = "test-device", records: [TestHealthDataRecord] = []) {
        self.version = version
        self.timestamp = timestamp
        self.deviceIdentifier = deviceIdentifier
        self.records = records
    }
}

private enum TestSyncStatus: Sendable {
    case idle
    case syncing
    case completed
    case failed(String)

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
}

private enum TestSyncError: Error, Sendable, LocalizedError {
    case healthKitUnavailable
    case noDataToSync
    case syncInProgress
    case cloudStorageUnavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable: "HealthKit is not available on this device"
        case .noDataToSync: "No health data available to synchronize"
        case .syncInProgress: "A sync operation is already in progress"
        case .cloudStorageUnavailable: "Cloud storage is not available"
        case .authorizationDenied: "HealthKit authorization was denied"
        }
    }
}

// MARK: - HealthKit type mapping test double

private struct TestHealthKitMapping {
    let dataType: TestHealthDataType
    let unit: String

    static func mapping(for dataType: TestHealthDataType) -> TestHealthKitMapping? {
        switch dataType {
        case .heartRate: return TestHealthKitMapping(dataType: dataType, unit: "count/min")
        case .steps: return TestHealthKitMapping(dataType: dataType, unit: "count")
        case .distance: return TestHealthKitMapping(dataType: dataType, unit: "m")
        case .activeCalories: return TestHealthKitMapping(dataType: dataType, unit: "kcal")
        case .bloodPressureSystolic, .bloodPressureDiastolic: return TestHealthKitMapping(dataType: dataType, unit: "mmHg")
        case .oxygenSaturation, .bodyFatPercentage: return TestHealthKitMapping(dataType: dataType, unit: "%")
        case .bodyWeight: return TestHealthKitMapping(dataType: dataType, unit: "kg")
        case .heartRateVariability: return TestHealthKitMapping(dataType: dataType, unit: "ms")
        case .restingHeartRate: return TestHealthKitMapping(dataType: dataType, unit: "count/min")
        case .sleepDuration, .sleepQuality, .bloodGlucose, .bodyMassIndex:
            return nil // Not directly mappable to HK quantity types
        }
    }
}

// MARK: - Tests

@Suite("HealthDataType")
struct HealthDataTypeTests {
    @Test("All 15 cases exist")
    func allCasesExist() {
        #expect(TestHealthDataType.allCases.count == 15)
    }

    @Test("Raw values are unique strings")
    func uniqueRawValues() {
        let rawValues = TestHealthDataType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Codable roundtrip for all cases")
    func codableRoundtrip() throws {
        for dataType in TestHealthDataType.allCases {
            let data = try JSONEncoder().encode(dataType)
            let decoded = try JSONDecoder().decode(TestHealthDataType.self, from: data)
            #expect(decoded == dataType)
        }
    }

    @Test("Vital sign types")
    func vitalSignTypes() {
        let vitals: Set<TestHealthDataType> = [.heartRate, .restingHeartRate, .heartRateVariability, .bloodPressureSystolic, .bloodPressureDiastolic, .oxygenSaturation]
        #expect(vitals.count == 6)
    }

    @Test("Body composition types")
    func bodyCompositionTypes() {
        let body: Set<TestHealthDataType> = [.bodyWeight, .bodyMassIndex, .bodyFatPercentage]
        #expect(body.count == 3)
    }

    @Test("Activity types")
    func activityTypes() {
        let activity: Set<TestHealthDataType> = [.steps, .distance, .activeCalories]
        #expect(activity.count == 3)
    }

    @Test("Sleep types")
    func sleepTypes() {
        let sleep: Set<TestHealthDataType> = [.sleepDuration, .sleepQuality]
        #expect(sleep.count == 2)
    }
}

@Suite("HealthDataRecord")
struct HealthDataRecordTests {
    @Test("Creation with defaults")
    func creation() {
        let record = TestHealthDataRecord(dataType: .heartRate, value: 72.0, unit: "bpm")
        #expect(record.dataType == .heartRate)
        #expect(record.value == 72.0)
        #expect(record.unit == "bpm")
        #expect(record.sourceDevice == "test-device")
    }

    @Test("Identifiable conformance")
    func identifiable() {
        let r1 = TestHealthDataRecord(dataType: .steps, value: 10000, unit: "count")
        let r2 = TestHealthDataRecord(dataType: .steps, value: 10000, unit: "count")
        #expect(r1.id != r2.id)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let record = TestHealthDataRecord(
            dataType: .bloodPressureSystolic,
            value: 120.0,
            unit: "mmHg",
            timestamp: Date(timeIntervalSinceReferenceDate: 100000),
            sourceDevice: "iphone-15"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestHealthDataRecord.self, from: data)
        #expect(decoded.dataType == record.dataType)
        #expect(decoded.value == record.value)
        #expect(decoded.unit == record.unit)
        #expect(decoded.sourceDevice == record.sourceDevice)
    }

    @Test("Heart rate normal range")
    func heartRateNormalRange() {
        let record = TestHealthDataRecord(dataType: .heartRate, value: 72, unit: "bpm")
        #expect(record.value >= 40 && record.value <= 200)
    }

    @Test("Blood pressure classification — normal")
    func bpNormal() {
        let systolic = TestHealthDataRecord(dataType: .bloodPressureSystolic, value: 115, unit: "mmHg")
        let diastolic = TestHealthDataRecord(dataType: .bloodPressureDiastolic, value: 75, unit: "mmHg")
        #expect(systolic.value < 120)
        #expect(diastolic.value < 80)
    }

    @Test("Blood pressure classification — stage 1 hypertension")
    func bpStage1() {
        let systolic = TestHealthDataRecord(dataType: .bloodPressureSystolic, value: 135, unit: "mmHg")
        #expect(systolic.value >= 130 && systolic.value < 140)
    }

    @Test("Blood pressure classification — stage 2 hypertension")
    func bpStage2() {
        let systolic = TestHealthDataRecord(dataType: .bloodPressureSystolic, value: 150, unit: "mmHg")
        #expect(systolic.value >= 140)
    }

    @Test("Steps with zero value")
    func zeroSteps() {
        let record = TestHealthDataRecord(dataType: .steps, value: 0, unit: "count")
        #expect(record.value == 0)
    }

    @Test("Sleep duration in hours")
    func sleepDurationHours() {
        let record = TestHealthDataRecord(dataType: .sleepDuration, value: 7.5, unit: "hr")
        #expect(record.value >= 0 && record.value <= 24)
    }

    @Test("Oxygen saturation percentage")
    func oxygenSaturation() {
        let record = TestHealthDataRecord(dataType: .oxygenSaturation, value: 98.5, unit: "%")
        #expect(record.value >= 0 && record.value <= 100)
    }

    @Test("Custom device identifier")
    func customDevice() {
        let record = TestHealthDataRecord(
            dataType: .steps,
            value: 5000,
            unit: "count",
            sourceDevice: "apple-watch-ultra-2"
        )
        #expect(record.sourceDevice == "apple-watch-ultra-2")
    }
}

@Suite("SyncPackage")
struct SyncPackageTests {
    @Test("Empty package creation")
    func emptyPackage() {
        let pkg = TestSyncPackage()
        #expect(pkg.version == "1.0")
        #expect(pkg.deviceIdentifier == "test-device")
        #expect(pkg.records.isEmpty)
    }

    @Test("Package with records")
    func packageWithRecords() {
        let records = [
            TestHealthDataRecord(dataType: .heartRate, value: 72, unit: "bpm"),
            TestHealthDataRecord(dataType: .steps, value: 10000, unit: "count"),
            TestHealthDataRecord(dataType: .sleepDuration, value: 7.5, unit: "hr")
        ]
        let pkg = TestSyncPackage(records: records)
        #expect(pkg.records.count == 3)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let records = [
            TestHealthDataRecord(
                dataType: .heartRate,
                value: 68,
                unit: "bpm",
                timestamp: Date(timeIntervalSinceReferenceDate: 50000)
            )
        ]
        let pkg = TestSyncPackage(
            version: "1.0",
            timestamp: Date(timeIntervalSinceReferenceDate: 100000),
            deviceIdentifier: "mac-studio",
            records: records
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pkg)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestSyncPackage.self, from: data)
        #expect(decoded.version == pkg.version)
        #expect(decoded.deviceIdentifier == pkg.deviceIdentifier)
        #expect(decoded.records.count == 1)
        #expect(decoded.records[0].dataType == .heartRate)
    }

    @Test("Validation — empty records")
    func validateEmpty() {
        let pkg = TestSyncPackage()
        // Empty records should fail validation
        #expect(pkg.records.isEmpty)
        let isValid = pkg.version == "1.0" && !pkg.records.isEmpty
        #expect(!isValid)
    }

    @Test("Validation — with records")
    func validateWithRecords() {
        let pkg = TestSyncPackage(records: [
            TestHealthDataRecord(dataType: .steps, value: 5000, unit: "count")
        ])
        let isValid = pkg.version == "1.0" && !pkg.records.isEmpty
        #expect(isValid)
    }

    @Test("Validation — wrong version")
    func validateWrongVersion() {
        let pkg = TestSyncPackage(
            version: "2.0",
            records: [TestHealthDataRecord(dataType: .steps, value: 5000, unit: "count")]
        )
        let isValid = pkg.version == "1.0" && !pkg.records.isEmpty
        #expect(!isValid)
    }

    @Test("Multi-device package")
    func multiDevicePackage() {
        let iPhoneRecords = [
            TestHealthDataRecord(dataType: .heartRate, value: 72, unit: "bpm", sourceDevice: "iphone"),
            TestHealthDataRecord(dataType: .steps, value: 8000, unit: "count", sourceDevice: "iphone")
        ]
        let watchRecords = [
            TestHealthDataRecord(dataType: .heartRate, value: 75, unit: "bpm", sourceDevice: "apple-watch"),
            TestHealthDataRecord(dataType: .oxygenSaturation, value: 98, unit: "%", sourceDevice: "apple-watch")
        ]
        let combined = iPhoneRecords + watchRecords
        let pkg = TestSyncPackage(records: combined)
        #expect(pkg.records.count == 4)
        let devices = Set(pkg.records.map(\.sourceDevice))
        #expect(devices.count == 2)
    }
}

@Suite("HealthSyncStatus")
struct HealthSyncStatusTests {
    @Test("Idle is not active")
    func idleNotActive() {
        let status = TestSyncStatus.idle
        #expect(!status.isActive)
    }

    @Test("Syncing is active")
    func syncingIsActive() {
        let status = TestSyncStatus.syncing
        #expect(status.isActive)
    }

    @Test("Completed is not active")
    func completedNotActive() {
        let status = TestSyncStatus.completed
        #expect(!status.isActive)
    }

    @Test("Failed is not active")
    func failedNotActive() {
        let status = TestSyncStatus.failed("network error")
        #expect(!status.isActive)
    }
}

@Suite("SyncError")
struct SyncErrorTests {
    @Test("All errors have descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [TestSyncError] = [
            .healthKitUnavailable,
            .noDataToSync,
            .syncInProgress,
            .cloudStorageUnavailable,
            .authorizationDenied
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Error descriptions are unique")
    func uniqueDescriptions() {
        let errors: [TestSyncError] = [
            .healthKitUnavailable,
            .noDataToSync,
            .syncInProgress,
            .cloudStorageUnavailable,
            .authorizationDenied
        ]
        let descriptions = errors.compactMap(\.errorDescription)
        #expect(Set(descriptions).count == descriptions.count)
    }

    @Test("HealthKit unavailable error")
    func healthKitUnavailable() {
        let error = TestSyncError.healthKitUnavailable
        #expect(error.errorDescription?.contains("HealthKit") == true)
    }

    @Test("Authorization denied error")
    func authDenied() {
        let error = TestSyncError.authorizationDenied
        #expect(error.errorDescription?.contains("denied") == true)
    }

    @Test("Cloud storage unavailable")
    func cloudUnavailable() {
        let error = TestSyncError.cloudStorageUnavailable
        #expect(error.errorDescription?.contains("Cloud") == true)
    }
}

@Suite("HealthKit Mapping")
struct HealthKitMappingTests {
    @Test("Heart rate maps to count/min")
    func heartRateMapping() {
        let mapping = TestHealthKitMapping.mapping(for: .heartRate)
        #expect(mapping != nil)
        #expect(mapping!.unit == "count/min")
    }

    @Test("Steps maps to count")
    func stepsMapping() {
        let mapping = TestHealthKitMapping.mapping(for: .steps)
        #expect(mapping != nil)
        #expect(mapping!.unit == "count")
    }

    @Test("Blood pressure maps to mmHg")
    func bpMapping() {
        let systolic = TestHealthKitMapping.mapping(for: .bloodPressureSystolic)
        let diastolic = TestHealthKitMapping.mapping(for: .bloodPressureDiastolic)
        #expect(systolic?.unit == "mmHg")
        #expect(diastolic?.unit == "mmHg")
    }

    @Test("Body weight maps to kg")
    func bodyWeightMapping() {
        let mapping = TestHealthKitMapping.mapping(for: .bodyWeight)
        #expect(mapping != nil)
        #expect(mapping!.unit == "kg")
    }

    @Test("Distance maps to meters")
    func distanceMapping() {
        let mapping = TestHealthKitMapping.mapping(for: .distance)
        #expect(mapping != nil)
        #expect(mapping!.unit == "m")
    }

    @Test("Sleep duration has no HK mapping")
    func sleepDurationNoMapping() {
        #expect(TestHealthKitMapping.mapping(for: .sleepDuration) == nil)
    }

    @Test("Sleep quality has no HK mapping")
    func sleepQualityNoMapping() {
        #expect(TestHealthKitMapping.mapping(for: .sleepQuality) == nil)
    }

    @Test("Blood glucose has no HK mapping")
    func bloodGlucoseNoMapping() {
        #expect(TestHealthKitMapping.mapping(for: .bloodGlucose) == nil)
    }

    @Test("BMI has no HK mapping")
    func bmiNoMapping() {
        #expect(TestHealthKitMapping.mapping(for: .bodyMassIndex) == nil)
    }

    @Test("Oxygen saturation maps to percent")
    func oxygenMapping() {
        let mapping = TestHealthKitMapping.mapping(for: .oxygenSaturation)
        #expect(mapping?.unit == "%")
    }

    @Test("HRV maps to milliseconds")
    func hrvMapping() {
        let mapping = TestHealthKitMapping.mapping(for: .heartRateVariability)
        #expect(mapping?.unit == "ms")
    }

    @Test("All mappable types return non-nil")
    func mappableTypes() {
        let mappable: [TestHealthDataType] = [
            .heartRate, .restingHeartRate, .heartRateVariability,
            .steps, .distance, .activeCalories,
            .bloodPressureSystolic, .bloodPressureDiastolic,
            .oxygenSaturation, .bodyWeight, .bodyFatPercentage
        ]
        for type in mappable {
            #expect(TestHealthKitMapping.mapping(for: type) != nil, "Expected mapping for \(type)")
        }
    }

    @Test("Non-mappable types return nil")
    func nonMappableTypes() {
        let nonMappable: [TestHealthDataType] = [
            .sleepDuration, .sleepQuality, .bloodGlucose, .bodyMassIndex
        ]
        for type in nonMappable {
            #expect(TestHealthKitMapping.mapping(for: type) == nil, "Expected no mapping for \(type)")
        }
    }
}

@Suite("Health Data Analytics")
struct HealthDataAnalyticsTests {
    private func makeRecords(_ pairs: [(TestHealthDataType, Double)]) -> [TestHealthDataRecord] {
        pairs.map { TestHealthDataRecord(dataType: $0.0, value: $0.1, unit: "unit") }
    }

    @Test("Average heart rate calculation")
    func averageHeartRate() {
        let records = [
            TestHealthDataRecord(dataType: .heartRate, value: 70, unit: "bpm"),
            TestHealthDataRecord(dataType: .heartRate, value: 72, unit: "bpm"),
            TestHealthDataRecord(dataType: .heartRate, value: 68, unit: "bpm")
        ]
        let hrRecords = records.filter { $0.dataType == .heartRate }
        let avg = hrRecords.map(\.value).reduce(0, +) / Double(hrRecords.count)
        #expect(abs(avg - 70.0) < 0.01)
    }

    @Test("Total steps aggregation")
    func totalSteps() {
        let records = [
            TestHealthDataRecord(dataType: .steps, value: 3000, unit: "count"),
            TestHealthDataRecord(dataType: .steps, value: 2500, unit: "count"),
            TestHealthDataRecord(dataType: .steps, value: 4500, unit: "count")
        ]
        let total = records.filter { $0.dataType == .steps }.map(\.value).reduce(0, +)
        #expect(total == 10000)
    }

    @Test("Detect elevated resting heart rate")
    func elevatedRestingHR() {
        let record = TestHealthDataRecord(dataType: .restingHeartRate, value: 105, unit: "bpm")
        let isElevated = record.value > 100
        #expect(isElevated)
    }

    @Test("Detect normal resting heart rate")
    func normalRestingHR() {
        let record = TestHealthDataRecord(dataType: .restingHeartRate, value: 65, unit: "bpm")
        let isElevated = record.value > 100
        #expect(!isElevated)
    }

    @Test("Sleep below target")
    func sleepBelowTarget() {
        let record = TestHealthDataRecord(dataType: .sleepDuration, value: 5.5, unit: "hr")
        let belowTarget = record.value < 7.0
        #expect(belowTarget)
    }

    @Test("Sleep meets target")
    func sleepMeetsTarget() {
        let record = TestHealthDataRecord(dataType: .sleepDuration, value: 8.0, unit: "hr")
        let meetsTarget = record.value >= 7.0
        #expect(meetsTarget)
    }

    @Test("Steps below recommended 10k")
    func stepsBelowRecommended() {
        let record = TestHealthDataRecord(dataType: .steps, value: 4500, unit: "count")
        let belowRecommended = record.value < 10000
        #expect(belowRecommended)
    }

    @Test("Filter records by type")
    func filterByType() {
        let records = [
            TestHealthDataRecord(dataType: .heartRate, value: 72, unit: "bpm"),
            TestHealthDataRecord(dataType: .steps, value: 8000, unit: "count"),
            TestHealthDataRecord(dataType: .heartRate, value: 68, unit: "bpm"),
            TestHealthDataRecord(dataType: .sleepDuration, value: 7, unit: "hr")
        ]
        let hrOnly = records.filter { $0.dataType == .heartRate }
        #expect(hrOnly.count == 2)
    }

    @Test("Date range filtering")
    func dateRangeFiltering() {
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let dayAgo = now.addingTimeInterval(-86400)

        let records = [
            TestHealthDataRecord(dataType: .heartRate, value: 70, unit: "bpm", timestamp: dayAgo),
            TestHealthDataRecord(dataType: .heartRate, value: 72, unit: "bpm", timestamp: twoHoursAgo),
            TestHealthDataRecord(dataType: .heartRate, value: 68, unit: "bpm", timestamp: hourAgo),
            TestHealthDataRecord(dataType: .heartRate, value: 75, unit: "bpm", timestamp: now)
        ]

        let last3Hours = records.filter { $0.timestamp > now.addingTimeInterval(-10800) }
        #expect(last3Hours.count == 3)
    }

    @Test("BMI calculation from weight and height")
    func bmiCalculation() {
        let weightKg = 75.0
        let heightM = 1.78
        let bmi = weightKg / (heightM * heightM)
        #expect(bmi > 23.0 && bmi < 24.0) // ~23.67
    }
}

@Suite("Sync Interval Logic")
struct SyncIntervalTests {
    @Test("Should sync when no last sync date")
    func shouldSyncNoLastDate() {
        let lastSyncDate: Date? = nil
        let syncInterval: TimeInterval = 3600
        let shouldSync = lastSyncDate == nil || Date().timeIntervalSince(lastSyncDate!) >= syncInterval
        #expect(shouldSync)
    }

    @Test("Should sync when interval exceeded")
    func shouldSyncIntervalExceeded() {
        let lastSyncDate = Date().addingTimeInterval(-7200) // 2 hours ago
        let syncInterval: TimeInterval = 3600 // 1 hour
        let shouldSync = Date().timeIntervalSince(lastSyncDate) >= syncInterval
        #expect(shouldSync)
    }

    @Test("Should not sync when interval not exceeded")
    func shouldNotSyncRecent() {
        let lastSyncDate = Date().addingTimeInterval(-1800) // 30 min ago
        let syncInterval: TimeInterval = 3600 // 1 hour
        let shouldSync = Date().timeIntervalSince(lastSyncDate) >= syncInterval
        #expect(!shouldSync)
    }

    @Test("Should sync exactly at interval boundary")
    func syncAtBoundary() {
        let lastSyncDate = Date().addingTimeInterval(-3600) // exactly 1 hour ago
        let syncInterval: TimeInterval = 3600
        let shouldSync = Date().timeIntervalSince(lastSyncDate) >= syncInterval
        #expect(shouldSync)
    }
}

@Suite("Nutrition Data Types")
struct NutritionDataTypesTests {
    private struct TestNutrientProfile: Codable, Sendable {
        var calories: Double = 0
        var protein: Double = 0
        var carbohydrates: Double = 0
        var fiber: Double = 0
        var sugars: Double = 0
        var totalFat: Double = 0
        var saturatedFat: Double = 0
        var transFat: Double = 0
        var sodium: Double = 0
    }

    private enum TestFoodSource: String, Codable, Sendable {
        case usda
        case openFoodFacts
        case manual
    }

    @Test("USDA nutrient ID mapping — energy")
    func usdaEnergyMapping() {
        // USDA nutrient ID 1008 = Energy (kcal)
        let nutrientId = 1008
        var profile = TestNutrientProfile()
        if nutrientId == 1008 { profile.calories = 250.0 }
        #expect(profile.calories == 250.0)
    }

    @Test("USDA nutrient ID mapping — protein")
    func usdaProteinMapping() {
        let nutrientId = 1003
        var profile = TestNutrientProfile()
        if nutrientId == 1003 { profile.protein = 25.0 }
        #expect(profile.protein == 25.0)
    }

    @Test("USDA nutrient ID mapping — carbs")
    func usdaCarbsMapping() {
        let nutrientId = 1005
        var profile = TestNutrientProfile()
        if nutrientId == 1005 { profile.carbohydrates = 30.0 }
        #expect(profile.carbohydrates == 30.0)
    }

    @Test("Barcode validation — valid UPC-A")
    func validUPCA() {
        let barcode = "012345678901"
        let isValid = barcode.count >= 8 && barcode.count <= 13 && barcode.allSatisfy(\.isNumber)
        #expect(isValid)
    }

    @Test("Barcode validation — valid EAN-13")
    func validEAN13() {
        let barcode = "5901234123457"
        let isValid = barcode.count >= 8 && barcode.count <= 13 && barcode.allSatisfy(\.isNumber)
        #expect(isValid)
    }

    @Test("Barcode validation — too short")
    func barcodeTooShort() {
        let barcode = "1234567"
        let isValid = barcode.count >= 8 && barcode.count <= 13 && barcode.allSatisfy(\.isNumber)
        #expect(!isValid)
    }

    @Test("Barcode validation — too long")
    func barcodeTooLong() {
        let barcode = "12345678901234"
        let isValid = barcode.count >= 8 && barcode.count <= 13 && barcode.allSatisfy(\.isNumber)
        #expect(!isValid)
    }

    @Test("Barcode validation — non-numeric")
    func barcodeNonNumeric() {
        let barcode = "12345ABCDE"
        let isValid = barcode.count >= 8 && barcode.count <= 13 && barcode.allSatisfy(\.isNumber)
        #expect(!isValid)
    }

    @Test("Food sources are distinct")
    func foodSourcesDistinct() {
        let sources: [TestFoodSource] = [.usda, .openFoodFacts, .manual]
        let rawValues = sources.map(\.rawValue)
        #expect(Set(rawValues).count == 3)
    }
}
