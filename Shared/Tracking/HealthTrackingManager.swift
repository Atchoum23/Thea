import Foundation
import Observation
@preconcurrency import SwiftData

#if os(iOS) || os(watchOS)
import HealthKit

// MARK: - Health Tracking Manager
// Integrates with HealthKit for comprehensive health data tracking

@MainActor
@Observable
final class HealthTrackingManager {
    static let shared = HealthTrackingManager()

    private var modelContext: ModelContext?
    private let healthStore = HKHealthStore()

    private(set) var isAuthorized = false
    private(set) var isMonitoring = false

    private var config: LifeTrackingConfiguration {
        AppConfiguration.shared.lifeTrackingConfig
    }

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthTrackingError.healthKitNotAvailable
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Real-time Monitoring

    func startRealTimeMonitoring() {
        guard config.healthTrackingEnabled, isAuthorized else { return }

        isMonitoring = true

        Task {
            while isMonitoring {
                await syncHealthData()
                try? await Task.sleep(nanoseconds: UInt64(config.healthSyncInterval * 1_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    // MARK: - Data Syncing

    private func syncHealthData() async {
        let snapshot = await fetchDailySnapshot(for: Date())
        await saveSnapshot(snapshot)
    }

    func fetchDailySnapshot(for date: Date) async -> HealthSnapshot {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        async let steps = fetchSteps(from: startOfDay, to: endOfDay)
        async let calories = fetchActiveCalories(from: startOfDay, to: endOfDay)
        async let heartRate = fetchHeartRateStatistics(from: startOfDay, to: endOfDay)
        async let sleep = fetchSleepDuration(from: startOfDay, to: endOfDay)
        async let workouts = fetchWorkoutMinutes(from: startOfDay, to: endOfDay)

        let (stepsValue, caloriesValue, hrStats, sleepValue, workoutValue) = await (steps, calories, heartRate, sleep, workouts)

        return HealthSnapshot(
            date: startOfDay,
            steps: stepsValue,
            activeCalories: caloriesValue,
            heartRateAverage: hrStats.average,
            heartRateMin: hrStats.min,
            heartRateMax: hrStats.max,
            sleepDuration: sleepValue,
            workoutMinutes: workoutValue
        )
    }

    // MARK: - Individual Metrics

    private func fetchSteps(from start: Date, to end: Date) async -> Int {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    private func fetchActiveCalories(from start: Date, to end: Date) async -> Double {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }

    private func fetchHeartRateStatistics(from start: Date, to end: Date) async -> (average: Double?, min: Double?, max: Double?) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil, nil)
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMin, .discreteMax]) { _, result, _ in
                let average = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let min = result?.minimumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let max = result?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: (average, min, max))
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepDuration(from start: Date, to end: Date) async -> TimeInterval {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let sleepSamples = samples as? [HKCategorySample] ?? []
                let totalDuration = sleepSamples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                continuation.resume(returning: totalDuration)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkoutMinutes(from start: Date, to end: Date) async -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                let totalMinutes = workouts.reduce(0.0) { total, workout in
                    total + workout.duration
                } / 60.0
                continuation.resume(returning: Int(totalMinutes))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Data Persistence

    private func saveSnapshot(_ snapshot: HealthSnapshot) async {
        guard let context = modelContext else { return }

        // Check if snapshot for this date already exists - fetch all and filter to avoid Swift 6 #Predicate Sendable issues
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: snapshot.date)

        let descriptor = FetchDescriptor<HealthSnapshot>()
        let allSnapshots = (try? context.fetch(descriptor)) ?? []

        if let existing = allSnapshots.first(where: { $0.date == startOfDay }) {
            // Update existing
            existing.steps = snapshot.steps
            existing.activeCalories = snapshot.activeCalories
            existing.heartRateAverage = snapshot.heartRateAverage
            existing.heartRateMin = snapshot.heartRateMin
            existing.heartRateMax = snapshot.heartRateMax
            existing.sleepDuration = snapshot.sleepDuration
            existing.workoutMinutes = snapshot.workoutMinutes
        } else {
            // Insert new
            context.insert(snapshot)
        }

        try? context.save()
    }

    // MARK: - Data Retrieval

    func getSnapshot(for date: Date) async -> HealthSnapshot? {
        guard let context = modelContext else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<HealthSnapshot>()
        let allSnapshots = (try? context.fetch(descriptor)) ?? []
        return allSnapshots.first { $0.date == startOfDay }
    }

    func getSnapshots(from start: Date, to end: Date) async -> [HealthSnapshot] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<HealthSnapshot>()
        let allSnapshots = (try? context.fetch(descriptor)) ?? []
        return allSnapshots
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Errors

enum HealthTrackingError: LocalizedError {
    case healthKitNotAvailable
    case authorizationDenied
    case dataNotAvailable

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "Health data access was denied"
        case .dataNotAvailable:
            return "Health data is not available for the requested period"
        }
    }
}

#else
// Placeholder for non-iOS/watchOS platforms
@MainActor
@Observable
final class HealthTrackingManager {
    static let shared = HealthTrackingManager()
    private init() {}
    func setModelContext(_ context: ModelContext) {}
}
#endif
