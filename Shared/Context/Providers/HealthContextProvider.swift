import Foundation
import os.log
#if canImport(HealthKit)
    import HealthKit
#endif

// MARK: - Health Context Provider

/// Provides health-related context from HealthKit
public actor HealthContextProvider: ContextProvider {
    public let providerId = "health"
    public let displayName = "Health"

    private let logger = Logger(subsystem: "app.thea", category: "HealthProvider")

    #if canImport(HealthKit) && !os(tvOS)
        private let healthStore = HKHealthStore()
        private var observerQueries: [HKObserverQuery] = []
    #endif

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?

    // Cached values
    private var cachedSteps: Double?
    private var cachedHeartRate: Double?
    private var cachedActiveEnergy: Double?
    private var cachedSleepHours: Double?

    public var isActive: Bool { state == .running }
    public var requiresPermission: Bool { true }

    public var hasPermission: Bool {
        get async {
            #if canImport(HealthKit) && !os(tvOS)
                guard HKHealthStore.isHealthDataAvailable() else { return false }
                let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
                let status = healthStore.authorizationStatus(for: stepType)
                return status == .sharingAuthorized
            #else
                return false
            #endif
        }
    }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        #if canImport(HealthKit) && !os(tvOS)
            guard HKHealthStore.isHealthDataAvailable() else {
                throw ContextProviderError.notAvailable
            }

            guard state != .running else {
                throw ContextProviderError.alreadyRunning
            }

            state = .starting

            // Setup observer queries for real-time updates
            await setupObserverQueries()

            // Start periodic updates
            updateTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.fetchHealthData()
                    do {
                        try await Task.sleep(for: .seconds(60))
                    } catch {
                        break // Task cancelled — stop periodic updates
                    }
                }
            }

            state = .running
            logger.info("Health provider started")
        #else
            throw ContextProviderError.notAvailable
        #endif
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        #if canImport(HealthKit) && !os(tvOS)
            for query in observerQueries {
                healthStore.stop(query)
            }
            observerQueries.removeAll()
        #endif

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Health provider stopped")
    }

    public func requestPermission() async throws -> Bool {
        #if canImport(HealthKit) && !os(tvOS)
            guard HKHealthStore.isHealthDataAvailable() else { return false }

            let typesToRead: Set<HKObjectType> = [
                HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
                HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
                HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
                HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
                HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            ]

            do {
                try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
                return true
            } catch {
                logger.error("Failed to request HealthKit permission: \(error.localizedDescription)")
                return false
            }
        #else
            return false
        #endif
    }

    public func getCurrentContext() async -> ContextUpdate? {
        await fetchHealthData()

        let context = HealthContext(
            stepCount: cachedSteps,
            heartRate: cachedHeartRate,
            heartRateVariability: nil,
            activeEnergyBurned: cachedActiveEnergy,
            restingHeartRate: nil,
            sleepHoursLastNight: cachedSleepHours,
            sleepQuality: determineSleepQuality(),
            activityLevel: determineActivityLevel(),
            stressLevel: nil,
            bloodOxygen: nil,
            respiratoryRate: nil
        )

        return ContextUpdate(
            providerId: providerId,
            updateType: .health(context),
            priority: .normal
        )
    }

    // MARK: - Private Methods

    #if canImport(HealthKit) && !os(tvOS)
        private func setupObserverQueries() async {
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

            // Observer for steps
            // IMPORTANT: completionHandler MUST always be called or HealthKit stops background delivery
            let stepQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    Task { await self?.fetchHealthData() }
                }
                completionHandler()
            }
            healthStore.execute(stepQuery)
            observerQueries.append(stepQuery)

            // Observer for heart rate
            let hrQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
                if error == nil {
                    Task { await self?.fetchHealthData() }
                }
                completionHandler()
            }
            healthStore.execute(hrQuery)
            observerQueries.append(hrQuery)
        }
    #endif

    private func fetchHealthData() async {
        #if canImport(HealthKit) && !os(tvOS)
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchSteps() }
                group.addTask { await self.fetchHeartRate() }
                group.addTask { await self.fetchActiveEnergy() }
                group.addTask { await self.fetchSleep() }
            }

            // Emit update
            let context = HealthContext(
                stepCount: cachedSteps,
                heartRate: cachedHeartRate,
                heartRateVariability: nil,
                activeEnergyBurned: cachedActiveEnergy,
                restingHeartRate: nil,
                sleepHoursLastNight: cachedSleepHours,
                sleepQuality: determineSleepQuality(),
                activityLevel: determineActivityLevel(),
                stressLevel: nil,
                bloodOxygen: nil,
                respiratoryRate: nil
            )

            let update = ContextUpdate(
                providerId: providerId,
                updateType: .health(context),
                priority: .normal
            )
            continuation?.yield(update)
        #endif
    }

    #if canImport(HealthKit) && !os(tvOS)
        private func fetchSteps() async {
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            do {
                let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics, Error>) in
                    let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let statistics {
                            continuation.resume(returning: statistics)
                        } else {
                            continuation.resume(throwing: ContextProviderError.updateFailed(NSError(domain: "HealthKit", code: -1)))
                        }
                    }
                    healthStore.execute(query)
                }

                cachedSteps = statistics.sumQuantity()?.doubleValue(for: .count())
            } catch {
                logger.error("Failed to fetch steps: \(error.localizedDescription)")
            }
        }

        private func fetchHeartRate() async {
            let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            do {
                let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                    let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: samples ?? [])
                        }
                    }
                    healthStore.execute(query)
                }

                if let sample = samples.first as? HKQuantitySample {
                    cachedHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                }
            } catch {
                logger.error("Failed to fetch heart rate: \(error.localizedDescription)")
            }
        }

        private func fetchActiveEnergy() async {
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            do {
                let statistics = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics, Error>) in
                    let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let statistics {
                            continuation.resume(returning: statistics)
                        } else {
                            continuation.resume(throwing: ContextProviderError.updateFailed(NSError(domain: "HealthKit", code: -1)))
                        }
                    }
                    healthStore.execute(query)
                }

                cachedActiveEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
            } catch {
                logger.error("Failed to fetch active energy: \(error.localizedDescription)")
            }
        }

        private func fetchSleep() async {
            let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            let now = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
            let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            do {
                let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                    let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: samples ?? [])
                        }
                    }
                    healthStore.execute(query)
                }

                // Calculate total sleep hours
                var totalSleep: TimeInterval = 0
                for sample in samples {
                    if let categorySample = sample as? HKCategorySample {
                        let value = HKCategoryValueSleepAnalysis(rawValue: categorySample.value)
                        if value == .asleepCore || value == .asleepDeep || value == .asleepREM || value == .asleepUnspecified {
                            totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                }
                cachedSleepHours = totalSleep / 3600.0
            } catch {
                logger.error("Failed to fetch sleep: \(error.localizedDescription)")
            }
        }
    #endif

    private func determineSleepQuality() -> HealthContext.SleepQuality? {
        guard let hours = cachedSleepHours else { return nil }
        if hours >= 7.5 { return .excellent }
        if hours >= 6.5 { return .good }
        if hours >= 5.0 { return .fair }
        return .poor
    }

    private func determineActivityLevel() -> HealthContext.ActivityLevel? {
        guard let steps = cachedSteps else { return nil }
        if steps >= 10000 { return .vigorous }
        if steps >= 7500 { return .moderate }
        if steps >= 5000 { return .light }
        return .sedentary
    }
}
