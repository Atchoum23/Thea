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
            modelContext = context
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
                    try? await Task.sleep(for: .seconds(config.healthSyncInterval))
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
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

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
            // Modern HKStatisticsQueryDescriptor — native async/await (iOS 15.4+/watchOS 8.5+)
            let stepsType = HKQuantityType(.stepCount)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: stepsType, predicate: predicate),
                options: .cumulativeSum
            )
            let result = try? await descriptor.result(for: healthStore)
            return Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        }

        private func fetchActiveCalories(from start: Date, to end: Date) async -> Double {
            // Modern HKStatisticsQueryDescriptor — native async/await (iOS 15.4+/watchOS 8.5+)
            let caloriesType = HKQuantityType(.activeEnergyBurned)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: caloriesType, predicate: predicate),
                options: .cumulativeSum
            )
            let result = try? await descriptor.result(for: healthStore)
            return result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }

        private func fetchHeartRateStatistics(from start: Date, to end: Date) async -> (average: Double?, min: Double?, max: Double?) {
            // Modern HKStatisticsQueryDescriptor — native async/await (iOS 15.4+/watchOS 8.5+)
            let heartRateType = HKQuantityType(.heartRate)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: heartRateType, predicate: predicate),
                options: [.discreteAverage, .discreteMin, .discreteMax]
            )
            let result = try? await descriptor.result(for: healthStore)
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let average = result?.averageQuantity()?.doubleValue(for: bpmUnit)
            let min = result?.minimumQuantity()?.doubleValue(for: bpmUnit)
            let max = result?.maximumQuantity()?.doubleValue(for: bpmUnit)
            return (average, min, max)
        }

        private func fetchSleepDuration(from start: Date, to end: Date) async -> TimeInterval {
            // Modern HKSampleQueryDescriptor — native async/await (iOS 15.4+/watchOS 8.5+)
            let sleepType = HKCategoryType(.sleepAnalysis)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: sleepType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
                limit: nil
            )
            let samples = (try? await descriptor.result(for: healthStore)) ?? []
            return samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
        }

        private func fetchWorkoutMinutes(from start: Date, to end: Date) async -> Int {
            // Modern HKSampleQueryDescriptor — native async/await (iOS 15.4+/watchOS 8.5+)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.sample(type: .workoutType(), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
                limit: nil
            )
            let samples = (try? await descriptor.result(for: healthStore)) ?? []
            let workouts = samples.compactMap { $0 as? HKWorkout }
            let totalMinutes = workouts.reduce(0.0) { total, workout in
                total + workout.duration
            } / 60.0
            return Int(totalMinutes)
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
                "HealthKit is not available on this device"
            case .authorizationDenied:
                "Health data access was denied"
            case .dataNotAvailable:
                "Health data is not available for the requested period"
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
        func setModelContext(_: ModelContext) {}
    }
#endif
