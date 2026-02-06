import Foundation

#if canImport(HealthKit)
    import HealthKit

    // MARK: - Array Extension for Async Map

    extension Array {
        func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
            var result: [T] = []
            for element in self {
                try await result.append(transform(element))
            }
            return result
        }
    }

    /// HealthKit service for iOS/watchOS health data integration
    public actor HealthKitService: HealthDataProvider {
        private let healthStore: HKHealthStore
        private var isAuthorized = false

        public init() {
            healthStore = HKHealthStore()
        }

        // MARK: - Authorization

        public func requestAuthorization() async throws -> Bool {
            guard HKHealthStore.isHealthDataAvailable() else {
                throw HealthError.healthKitUnavailable
            }

            let typesToRead: Set<HKObjectType> = [
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
                HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
                HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
                HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            ]

            do {
                try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
                isAuthorized = true
                return true
            } catch {
                throw HealthError.authorizationDenied
            }
        }

        // MARK: - Sleep Data

        public func fetchSleepData(for dateRange: DateInterval) async throws -> [SleepRecord] {
            guard isAuthorized else {
                throw HealthError.authorizationDenied
            }

            guard dateRange.duration > 0 else {
                throw HealthError.invalidDateRange
            }

            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let predicate = HKQuery.predicateForSamples(
                withStart: dateRange.start,
                end: dateRange.end,
                options: .strictStartDate
            )

            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { [weak self] _, samples, error in
                    if let error {
                        continuation.resume(throwing: HealthError.fetchFailed(error.localizedDescription))
                        return
                    }

                    guard let samples = samples as? [HKCategorySample], let self else {
                        continuation.resume(returning: [])
                        return
                    }

                    Task {
                        let records = await self.processSleepSamples(samples)
                        continuation.resume(returning: records)
                    }
                }

                healthStore.execute(query)
            }
        }

        private func processSleepSamples(_ samples: [HKCategorySample]) -> [SleepRecord] {
            var sleepSessions: [[HKCategorySample]] = []
            var currentSession: [HKCategorySample] = []

            for sample in samples {
                if currentSession.isEmpty {
                    currentSession.append(sample)
                } else if let last = currentSession.last,
                          sample.startDate.timeIntervalSince(last.endDate) < 3600
                { // 1 hour gap
                    currentSession.append(sample)
                } else {
                    sleepSessions.append(currentSession)
                    currentSession = [sample]
                }
            }

            if !currentSession.isEmpty {
                sleepSessions.append(currentSession)
            }

            return sleepSessions.compactMap { session -> SleepRecord? in
                guard let firstSample = session.first,
                      let lastSample = session.last
                else {
                    return nil
                }

                let stages = session.map { sample -> SleepStageSegment in
                    let stage = mapSleepStage(sample.value)
                    return SleepStageSegment(
                        stage: stage,
                        startDate: sample.startDate,
                        endDate: sample.endDate
                    )
                }

                let totalMinutes = Int((lastSample.endDate.timeIntervalSince(firstSample.startDate)) / 60)
                let deepMinutes = stages.filter { $0.stage == .deep }.reduce(0) { $0 + $1.durationMinutes }
                let remMinutes = stages.filter { $0.stage == .rem }.reduce(0) { $0 + $1.durationMinutes }
                let awakeMinutes = stages.filter { $0.stage == .awake }.reduce(0) { $0 + $1.durationMinutes }

                let quality = SleepQuality.calculate(
                    totalMinutes: totalMinutes,
                    deepMinutes: deepMinutes,
                    remMinutes: remMinutes,
                    awakeMinutes: awakeMinutes
                )

                return SleepRecord(
                    startDate: firstSample.startDate,
                    endDate: lastSample.endDate,
                    stages: stages,
                    quality: quality,
                    source: .healthKit
                )
            }
        }

        private func mapSleepStage(_ value: Int) -> SleepStage {
            switch value {
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                 HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                .light
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                .deep
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                .rem
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                .awake
            default:
                .light
            }
        }

        // MARK: - Heart Rate Data

        public func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HeartRateRecord] {
            guard isAuthorized else {
                throw HealthError.authorizationDenied
            }

            guard dateRange.duration > 0 else {
                throw HealthError.invalidDateRange
            }

            let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
            let predicate = HKQuery.predicateForSamples(
                withStart: dateRange.start,
                end: dateRange.end,
                options: .strictStartDate
            )

            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { [weak self] _, samples, error in
                    if let error {
                        continuation.resume(throwing: HealthError.fetchFailed(error.localizedDescription))
                        return
                    }

                    guard let samples = samples as? [HKQuantitySample], let self else {
                        continuation.resume(returning: [])
                        return
                    }

                    Task {
                        let records = await samples.asyncMap { sample -> HeartRateRecord in
                            let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())))
                            let context = await self.determineHeartRateContext(bpm: bpm, date: sample.startDate)

                            return HeartRateRecord(
                                timestamp: sample.startDate,
                                beatsPerMinute: bpm,
                                context: context,
                                source: .healthKit
                            )
                        }

                        continuation.resume(returning: records)
                    }
                }

                healthStore.execute(query)
            }
        }

        private func determineHeartRateContext(bpm: Int, date: Date) -> HeartRateContext {
            let hour = Calendar.current.component(.hour, from: date)

            // Simple heuristic based on time and heart rate
            if hour >= 22 || hour <= 6 {
                return .sleep
            } else if bpm < 80 {
                return .resting
            } else if bpm < 120 {
                return .active
            } else {
                return .workout
            }
        }

        // MARK: - Activity Data

        public func fetchActivityData(for date: Date) async throws -> ActivitySummary {
            guard isAuthorized else {
                throw HealthError.authorizationDenied
            }

            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

            async let steps = fetchQuantitySum(
                identifier: .stepCount,
                start: startOfDay,
                end: endOfDay
            )

            async let activeCalories = fetchQuantitySum(
                identifier: .activeEnergyBurned,
                start: startOfDay,
                end: endOfDay
            )

            async let totalCalories = fetchQuantitySum(
                identifier: .basalEnergyBurned,
                start: startOfDay,
                end: endOfDay
            )

            async let distance = fetchQuantitySum(
                identifier: .distanceWalkingRunning,
                start: startOfDay,
                end: endOfDay
            )

            async let activeMinutes = fetchQuantitySum(
                identifier: .appleExerciseTime,
                start: startOfDay,
                end: endOfDay
            )

            async let flights = fetchQuantitySum(
                identifier: .flightsClimbed,
                start: startOfDay,
                end: endOfDay
            )

            let (stepsValue, activeCalValue, totalCalValue, distValue, activeMinValue, flightsValue) =
                try await (steps, activeCalories, totalCalories, distance, activeMinutes, flights)

            return ActivitySummary(
                date: date,
                steps: Int(stepsValue),
                activeCalories: Int(activeCalValue),
                totalCalories: Int(totalCalValue + activeCalValue),
                distance: distValue,
                activeMinutes: Int(activeMinValue),
                flightsClimbed: Int(flightsValue),
                source: .healthKit
            )
        }

        private func fetchQuantitySum(
            identifier: HKQuantityTypeIdentifier,
            start: Date,
            end: Date
        ) async throws -> Double {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
                return 0
            }

            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

            return try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let unit = switch identifier {
                    case .stepCount, .flightsClimbed:
                        HKUnit.count()
                    case .activeEnergyBurned, .basalEnergyBurned:
                        HKUnit.kilocalorie()
                    case .distanceWalkingRunning:
                        HKUnit.meter()
                    case .appleExerciseTime:
                        HKUnit.minute()
                    default:
                        HKUnit.count()
                    }

                    let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                    continuation.resume(returning: sum)
                }

                healthStore.execute(query)
            }
        }

        // MARK: - Blood Pressure Data

        public func fetchBloodPressureData(for dateRange: DateInterval) async throws -> [BloodPressureReading] {
            guard isAuthorized else {
                throw HealthError.authorizationDenied
            }

            let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!

            let startDate = dateRange.start
            let endDate = dateRange.end

            async let systolicSamples = fetchQuantitySamples(
                type: systolicType,
                predicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            )
            async let diastolicSamples = fetchQuantitySamples(
                type: diastolicType,
                predicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            )

            let (systolic, diastolic) = try await (systolicSamples, diastolicSamples)

            // Match systolic and diastolic by timestamp
            var readings: [BloodPressureReading] = []
            for sysample in systolic {
                if let diasample = diastolic.first(where: { abs($0.startDate.timeIntervalSince(sysample.startDate)) < 60 }) {
                    let systolicValue = Int(sysample.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                    let diastolicValue = Int(diasample.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))

                    readings.append(BloodPressureReading(
                        timestamp: sysample.startDate,
                        systolic: systolicValue,
                        diastolic: diastolicValue,
                        source: .healthKit
                    ))
                }
            }

            return readings
        }

        nonisolated private func fetchQuantitySamples(
            type: HKQuantityType,
            predicate: NSPredicate
        ) async throws -> [HKQuantitySample] {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }

                healthStore.execute(query)
            }
        }

        // MARK: - Anomaly Detection

        public func detectCardiacAnomalies(in records: [HeartRateRecord]) async throws -> [CardiacAnomaly] {
            var anomalies: [CardiacAnomaly] = []

            for record in records {
                // Detect tachycardia (high heart rate)
                if record.context == .resting, record.beatsPerMinute > 100 {
                    let severity: CardiacAnomaly.Severity = record.beatsPerMinute > 120 ? .severe :
                        record.beatsPerMinute > 110 ? .moderate : .mild
                    anomalies.append(CardiacAnomaly(
                        timestamp: record.timestamp,
                        type: .tachycardia,
                        severity: severity,
                        heartRate: record.beatsPerMinute,
                        description: "Resting heart rate of \(record.beatsPerMinute) bpm is elevated."
                    ))
                }

                // Detect bradycardia (low heart rate)
                if record.context == .resting, record.beatsPerMinute < 60 {
                    let severity: CardiacAnomaly.Severity = record.beatsPerMinute < 40 ? .severe :
                        record.beatsPerMinute < 50 ? .moderate : .mild
                    anomalies.append(CardiacAnomaly(
                        timestamp: record.timestamp,
                        type: .bradycardia,
                        severity: severity,
                        heartRate: record.beatsPerMinute,
                        description: "Resting heart rate of \(record.beatsPerMinute) bpm is low."
                    ))
                }
            }

            return anomalies
        }
    }

#else

    /// Stub implementation for platforms without HealthKit
    public actor HealthKitService: HealthDataProvider {
        public init() {}

        public func requestAuthorization() async throws -> Bool {
            throw HealthError.healthKitUnavailable
        }

        public func fetchSleepData(for _: DateInterval) async throws -> [SleepRecord] {
            throw HealthError.healthKitUnavailable
        }

        public func fetchHeartRateData(for _: DateInterval) async throws -> [HeartRateRecord] {
            throw HealthError.healthKitUnavailable
        }

        public func fetchActivityData(for _: Date) async throws -> ActivitySummary {
            throw HealthError.healthKitUnavailable
        }

        public func fetchBloodPressureData(for _: DateInterval) async throws -> [BloodPressureReading] {
            throw HealthError.healthKitUnavailable
        }

        public func detectCardiacAnomalies(in _: [HeartRateRecord]) async throws -> [CardiacAnomaly] {
            throw HealthError.healthKitUnavailable
        }
    }

#endif
