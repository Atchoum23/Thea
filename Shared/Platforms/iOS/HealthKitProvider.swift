//
//  HealthKitProvider.swift
//  Thea
//
//  Created by Thea
//

#if os(iOS) || os(watchOS)
    import Foundation
    import HealthKit
    import os.log

    /// Provides health data integration using HealthKit
    /// Observes heart rate, steps, sleep, workouts, and more
    @MainActor
    public final class HealthKitProvider: ObservableObject {
        public static let shared = HealthKitProvider()

        private let logger = Logger(subsystem: "app.thea.health", category: "HealthKitProvider")

        // HealthKit store
        private let healthStore = HKHealthStore()

        // Authorization status
        @Published public private(set) var isAuthorized = false

        // Current health data
        @Published public private(set) var latestHeartRate: Double?
        @Published public private(set) var restingHeartRate: Double?
        @Published public private(set) var todaySteps: Int = 0
        @Published public private(set) var todayActiveEnergy: Double = 0
        @Published public private(set) var todaySleepHours: Double = 0
        @Published public private(set) var currentWorkout: WorkoutInfo?
        @Published public private(set) var latestBloodOxygen: Double?
        @Published public private(set) var latestHRV: Double?

        // Callbacks
        public var onHeartRateUpdated: ((Double) -> Void)?
        public var onWorkoutStarted: ((WorkoutInfo) -> Void)?
        public var onWorkoutEnded: ((WorkoutInfo) -> Void)?
        public var onHealthAnomalyDetected: ((HealthAnomaly) -> Void)?

        // Active queries
        private var heartRateQuery: HKObserverQuery?
        private var workoutQuery: HKObserverQuery?
        private var activeQueries: [HKQuery] = []

        private init() {}

        // MARK: - Availability

        /// Check if HealthKit is available on this device
        public var isAvailable: Bool {
            HKHealthStore.isHealthDataAvailable()
        }

        // MARK: - Authorization

        /// Request authorization for health data
        public func requestAuthorization() async throws {
            guard isAvailable else {
                logger.warning("HealthKit not available on this device")
                throw HealthKitError.notAvailable
            }

            let typesToRead = healthDataTypes()
            let typesToShare: Set<HKSampleType> = [] // Read-only for now

            do {
                try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
                isAuthorized = true
                logger.info("HealthKit authorization granted")
            } catch {
                logger.error("HealthKit authorization failed: \(error)")
                throw error
            }
        }

        private func healthDataTypes() -> Set<HKObjectType> {
            var types: Set<HKObjectType> = []

            // Vital signs
            if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
                types.insert(heartRate)
            }
            if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
                types.insert(restingHR)
            }
            if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                types.insert(hrv)
            }
            if let bloodOxygen = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
                types.insert(bloodOxygen)
            }
            if let respiratoryRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
                types.insert(respiratoryRate)
            }

            // Activity
            if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
                types.insert(steps)
            }
            if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                types.insert(activeEnergy)
            }
            if let standTime = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
                types.insert(standTime)
            }
            if let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
                types.insert(exerciseTime)
            }
            if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
                types.insert(distance)
            }

            // Sleep
            if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                types.insert(sleep)
            }

            // Workouts
            types.insert(HKObjectType.workoutType())

            return types
        }

        // MARK: - Monitoring

        /// Start monitoring health data
        public func startMonitoring() {
            guard isAuthorized else {
                logger.warning("Cannot start monitoring - not authorized")
                return
            }

            startHeartRateMonitoring()
            startWorkoutMonitoring()
            fetchTodayStats()

            logger.info("Health monitoring started")
        }

        /// Stop monitoring
        public func stopMonitoring() {
            for query in activeQueries {
                healthStore.stop(query)
            }
            activeQueries.removeAll()

            heartRateQuery = nil
            workoutQuery = nil

            logger.info("Health monitoring stopped")
        }

        // MARK: - Heart Rate

        private func startHeartRateMonitoring() {
            guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                return
            }

            let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error {
                    self?.logger.error("Heart rate observer error: \(error)")
                    completionHandler()
                    return
                }

                Task { @MainActor in
                    await self?.fetchLatestHeartRate()
                }
                completionHandler()
            }

            healthStore.execute(query)
            heartRateQuery = query
            activeQueries.append(query)

            // Fetch initial value
            Task {
                await fetchLatestHeartRate()
            }
        }

        private func fetchLatestHeartRate() async {
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { return }

                let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

                Task { @MainActor in
                    let previousRate = self?.latestHeartRate
                    self?.latestHeartRate = heartRate
                    self?.onHeartRateUpdated?(heartRate)

                    // Check for anomalies
                    if let previous = previousRate {
                        self?.checkHeartRateAnomaly(current: heartRate, previous: previous)
                    }
                }
            }

            healthStore.execute(query)
        }

        private func checkHeartRateAnomaly(current: Double, previous: Double) {
            // Sudden large change in heart rate
            let change = abs(current - previous)
            if change > 30 {
                let anomaly = HealthAnomaly(
                    type: .suddenHeartRateChange,
                    value: current,
                    previousValue: previous,
                    message: "Heart rate changed by \(Int(change)) bpm"
                )
                onHealthAnomalyDetected?(anomaly)
            }

            // High heart rate at rest
            if current > 100 {
                let anomaly = HealthAnomaly(
                    type: .highHeartRate,
                    value: current,
                    message: "Heart rate elevated: \(Int(current)) bpm"
                )
                onHealthAnomalyDetected?(anomaly)
            }

            // Low heart rate
            if current < 40 {
                let anomaly = HealthAnomaly(
                    type: .lowHeartRate,
                    value: current,
                    message: "Heart rate low: \(Int(current)) bpm"
                )
                onHealthAnomalyDetected?(anomaly)
            }
        }

        // MARK: - Workouts

        private func startWorkoutMonitoring() {
            let workoutType = HKObjectType.workoutType()

            let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error {
                    self?.logger.error("Workout observer error: \(error)")
                    completionHandler()
                    return
                }

                Task { @MainActor in
                    await self?.fetchLatestWorkout()
                }
                completionHandler()
            }

            healthStore.execute(query)
            workoutQuery = query
            activeQueries.append(query)
        }

        private func fetchLatestWorkout() async {
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let workout = samples?.first as? HKWorkout else { return }

                let workoutInfo = WorkoutInfo(from: workout)

                Task { @MainActor in
                    let wasInWorkout = self?.currentWorkout != nil
                    let isNowInWorkout = workout.endDate > Date().addingTimeInterval(-60) // Within last minute

                    if isNowInWorkout, !wasInWorkout {
                        self?.currentWorkout = workoutInfo
                        self?.onWorkoutStarted?(workoutInfo)
                    } else if wasInWorkout, !isNowInWorkout {
                        self?.currentWorkout = nil
                        self?.onWorkoutEnded?(workoutInfo)
                    }
                }
            }

            healthStore.execute(query)
        }

        // MARK: - Daily Stats

        private func fetchTodayStats() {
            Task {
                await fetchTodaySteps()
                await fetchTodayActiveEnergy()
                await fetchTodaySleep()
                await fetchRestingHeartRate()
                await fetchLatestHRV()
                await fetchLatestBloodOxygen()
            }
        }

        private func fetchTodaySteps() async {
            guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return
            }

            let startOfDay = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else { return }

                let steps = Int(sum.doubleValue(for: HKUnit.count()))

                Task { @MainActor in
                    self?.todaySteps = steps
                }
            }

            healthStore.execute(query)
        }

        private func fetchTodayActiveEnergy() async {
            guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                return
            }

            let startOfDay = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else { return }

                let calories = sum.doubleValue(for: HKUnit.kilocalorie())

                Task { @MainActor in
                    self?.todayActiveEnergy = calories
                }
            }

            healthStore.execute(query)
        }

        private func fetchTodaySleep() async {
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                return
            }

            // Look at yesterday's sleep ending today
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: endDate))!

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else { return }

                var totalSleep: TimeInterval = 0
                for sample in sleepSamples {
                    // Count asleep states (core, deep, REM, or unspecified asleep)
                    if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    {
                        totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let hours = totalSleep / 3600

                Task { @MainActor in
                    self?.todaySleepHours = hours
                }
            }

            healthStore.execute(query)
        }

        private func fetchRestingHeartRate() async {
            guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { return }

                let rate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

                Task { @MainActor in
                    self?.restingHeartRate = rate
                }
            }

            healthStore.execute(query)
        }

        private func fetchLatestHRV() async {
            guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { return }

                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

                Task { @MainActor in
                    self?.latestHRV = hrv
                }
            }

            healthStore.execute(query)
        }

        private func fetchLatestBloodOxygen() async {
            guard let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
                return
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: oxygenType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else { return }

                let percentage = sample.quantity.doubleValue(for: HKUnit.percent()) * 100

                Task { @MainActor in
                    self?.latestBloodOxygen = percentage
                }
            }

            healthStore.execute(query)
        }

        // MARK: - Queries

        /// Get health summary
        public var healthSummary: HealthSummary {
            HealthSummary(
                heartRate: latestHeartRate,
                restingHeartRate: restingHeartRate,
                hrv: latestHRV,
                bloodOxygen: latestBloodOxygen,
                todaySteps: todaySteps,
                todayActiveEnergy: todayActiveEnergy,
                todaySleepHours: todaySleepHours,
                currentWorkout: currentWorkout
            )
        }

        /// Check if user is likely sleeping
        public var isLikelySleeping: Bool {
            guard let heartRate = latestHeartRate,
                  let restingHR = restingHeartRate
            else {
                return false
            }

            // Heart rate close to or below resting, and it's nighttime
            let hour = Calendar.current.component(.hour, from: Date())
            let isNighttime = hour >= 22 || hour <= 6
            let heartRateLow = heartRate <= restingHR + 5

            return isNighttime && heartRateLow
        }

        /// Check if user is likely exercising
        public var isLikelyExercising: Bool {
            if currentWorkout != nil { return true }

            guard let heartRate = latestHeartRate,
                  let restingHR = restingHeartRate
            else {
                return false
            }

            // Heart rate significantly above resting
            return heartRate > restingHR * 1.3
        }
    }

    // Data models (HealthSummary, WorkoutInfo, HealthAnomaly, HealthKitError)
    // are in HealthKitProviderTypes.swift
#endif
