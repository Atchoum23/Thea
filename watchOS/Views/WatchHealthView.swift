// WatchHealthView.swift
// Thea watchOS — Glanceable Health Dashboard
//
// Self-contained watchOS health view with HealthKit queries.
// Shows today's key metrics in a compact, glanceable format.

import HealthKit
import SwiftUI

// MARK: - Watch Health View

/// Glanceable health dashboard for Apple Watch.
/// Shows today's key metrics: steps, heart rate, active energy, sleep.
@MainActor
struct WatchHealthView: View {
    @State private var viewModel = WatchHealthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.authorizationStatus == .notDetermined {
                    authorizationPrompt
                } else if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                } else {
                    metricsGrid
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Updated \(lastUpdated, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Health")
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    // MARK: - Authorization Prompt

    private var authorizationPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Health Access")
                .font(.headline)

            Text("Grant access to view your health data.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Authorize") {
                Task { await viewModel.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricCard(
                    icon: "figure.walk",
                    value: viewModel.formattedSteps,
                    label: "Steps",
                    color: .green
                )
                metricCard(
                    icon: "heart.fill",
                    value: viewModel.formattedHeartRate,
                    label: "BPM",
                    color: .red
                )
            }

            HStack(spacing: 8) {
                metricCard(
                    icon: "flame.fill",
                    value: viewModel.formattedActiveEnergy,
                    label: "kcal",
                    color: .orange
                )
                metricCard(
                    icon: "bed.double.fill",
                    value: viewModel.formattedSleep,
                    label: "Sleep",
                    color: .purple
                )
            }

            // Workout summary if available
            if let workout = viewModel.latestWorkout {
                workoutCard(workout)
            }
        }
    }

    // MARK: - Metric Card

    private func metricCard(
        icon: String, value: String, label: String, color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Workout Card

    private func workoutCard(_ workout: WatchWorkoutSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: workout.icon)
                .font(.system(size: 18))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName)
                    .font(.caption.bold())
                Text(workout.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let calories = workout.caloriesBurned {
                Text("\(Int(calories)) kcal")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .background(.cyan.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Latest workout: \(workout.activityName), \(workout.formattedDuration)")
    }
}

// MARK: - Watch Workout Summary

struct WatchWorkoutSummary {
    let activityName: String
    let icon: String
    let duration: TimeInterval
    let caloriesBurned: Double?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    let startDate: Date

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Watch Health ViewModel

@MainActor
@Observable
final class WatchHealthViewModel {
    private let healthStore = HKHealthStore()

    // State
    var isLoading = false
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var lastUpdated: Date?
    var errorMessage: String?

    // Metrics
    var steps: Int = 0
    var heartRate: Double = 0
    var activeEnergy: Double = 0
    var sleepHours: Double = 0
    var latestWorkout: WatchWorkoutSummary?

    // MARK: - Formatted Values

    var formattedSteps: String {
        if steps >= 10_000 {
            return String(format: "%.1fK", Double(steps) / 1_000)
        }
        return "\(steps)"
    }

    var formattedHeartRate: String {
        heartRate > 0 ? "\(Int(heartRate))" : "--"
    }

    var formattedActiveEnergy: String {
        if activeEnergy >= 1_000 {
            return String(format: "%.1fK", activeEnergy / 1_000)
        }
        return "\(Int(activeEnergy))"
    }

    var formattedSleep: String {
        if sleepHours <= 0 { return "--" }
        let hours = Int(sleepHours)
        let minutes = Int((sleepHours - Double(hours)) * 60)
        return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
    }

    // MARK: - Types to Read

    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepType)
        }
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(hrType)
        }
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energyType)
        }
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit not available"
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            authorizationStatus = .sharingAuthorized
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Data

    func loadData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Check authorization
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            authorizationStatus = healthStore.authorizationStatus(for: stepType)
        }

        guard authorizationStatus != .notDetermined else { return }

        isLoading = true
        defer { isLoading = false }

        async let stepsResult = fetchSteps()
        async let hrResult = fetchHeartRate()
        async let energyResult = fetchActiveEnergy()
        async let sleepResult = fetchSleepHours()
        async let workoutResult = fetchLatestWorkout()

        steps = await stepsResult
        heartRate = await hrResult
        activeEnergy = await energyResult
        sleepHours = await sleepResult
        latestWorkout = await workoutResult
        lastUpdated = Date()
    }

    // MARK: - Fetch Steps (Today)

    private func fetchSteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: Date(), options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let count = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Heart Rate (Latest)

    private func fetchHeartRate() async -> Double {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let bpm = sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Active Energy (Today)

    private func fetchActiveEnergy() async -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: Date(), options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let kcal = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Sleep Hours (Last Night)

    private func fetchSleepHours() async -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        // Look for sleep from 6pm yesterday to now
        let calendar = Calendar.current
        let now = Date()
        guard let yesterday6pm = calendar.date(
            bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        ) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: yesterday6pm, end: now, options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                // Sum asleep time (InBed, Asleep core/deep/REM, Unspecified)
                let totalSeconds = categorySamples
                    .filter { sample in
                        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                        return value != .inBed // Exclude awake-in-bed
                    }
                    .reduce(0.0) { sum, sample in
                        sum + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Latest Workout (Today)

    private func fetchLatestWorkout() async -> WatchWorkoutSummary? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: Date(), options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: nil)
                    return
                }
                let summary = WatchWorkoutSummary(
                    activityName: Self.activityName(for: workout.workoutActivityType),
                    icon: Self.activityIcon(for: workout.workoutActivityType),
                    duration: workout.duration,
                    caloriesBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                    startDate: workout.startDate
                )
                continuation.resume(returning: summary)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workout Helpers

    nonisolated private static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "Strength"
        case .highIntensityIntervalTraining: "HIIT"
        case .coreTraining: "Core"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairClimbing: "Stairs"
        case .dance: "Dance"
        case .pilates: "Pilates"
        default: "Workout"
        }
    }

    nonisolated private static func activityIcon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .yoga: "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "dumbbell.fill"
        case .highIntensityIntervalTraining: "bolt.heart.fill"
        default: "figure.mixed.cardio"
        }
    }
}
