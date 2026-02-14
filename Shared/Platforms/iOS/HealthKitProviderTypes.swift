// HealthKitProviderTypes.swift
// Supporting types for HealthKitProvider

#if os(iOS) || os(watchOS)
    import Foundation
    import HealthKit

    // MARK: - Data Models

    public struct HealthSummary: Sendable {
        public let heartRate: Double?
        public let restingHeartRate: Double?
        public let hrv: Double?
        public let bloodOxygen: Double?
        public let todaySteps: Int
        public let todayActiveEnergy: Double
        public let todaySleepHours: Double
        public let currentWorkout: WorkoutInfo?
        public let timestamp: Date

        init(
            heartRate: Double?,
            restingHeartRate: Double?,
            hrv: Double?,
            bloodOxygen: Double?,
            todaySteps: Int,
            todayActiveEnergy: Double,
            todaySleepHours: Double,
            currentWorkout: WorkoutInfo?
        ) {
            self.heartRate = heartRate
            self.restingHeartRate = restingHeartRate
            self.hrv = hrv
            self.bloodOxygen = bloodOxygen
            self.todaySteps = todaySteps
            self.todayActiveEnergy = todayActiveEnergy
            self.todaySleepHours = todaySleepHours
            self.currentWorkout = currentWorkout
            timestamp = Date()
        }

        public var formattedSleep: String {
            let hours = Int(todaySleepHours)
            let minutes = Int((todaySleepHours - Double(hours)) * 60)
            return "\(hours)h \(minutes)m"
        }

        public var formattedActiveEnergy: String {
            String(format: "%.0f kcal", todayActiveEnergy)
        }
    }

    public struct WorkoutInfo: Identifiable, Sendable {
        public let id: UUID
        public let activityType: HKWorkoutActivityType
        public let startDate: Date
        public let endDate: Date?
        public let duration: TimeInterval
        public let totalEnergyBurned: Double?
        public let totalDistance: Double?
        public let averageHeartRate: Double?

        init(from workout: HKWorkout) {
            id = workout.uuid
            activityType = workout.workoutActivityType
            startDate = workout.startDate
            endDate = workout.endDate
            duration = workout.duration
            // Use statistics API instead of deprecated totalEnergyBurned property
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let stats = workout.statistics(for: energyType),
               let sum = stats.sumQuantity()
            {
                totalEnergyBurned = sum.doubleValue(for: .kilocalorie())
            } else {
                totalEnergyBurned = nil
            }
            totalDistance = workout.totalDistance?.doubleValue(for: .meter())
            averageHeartRate = nil // Would need separate query
        }

        public var activityName: String {
            switch activityType {
            case .running: "Running"
            case .walking: "Walking"
            case .cycling: "Cycling"
            case .swimming: "Swimming"
            case .yoga: "Yoga"
            case .functionalStrengthTraining: "Strength Training"
            case .highIntensityIntervalTraining: "HIIT"
            case .coreTraining: "Core Training"
            case .crossTraining: "Cross Training"
            case .hiking: "Hiking"
            case .elliptical: "Elliptical"
            case .stairClimbing: "Stair Climbing"
            case .rowing: "Rowing"
            case .dance: "Dance"
            case .mindAndBody: "Mind & Body"
            default: "Workout"
            }
        }

        public var formattedDuration: String {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }

    public struct HealthAnomaly: Sendable {
        public let type: AnomalyType
        public let value: Double
        public let previousValue: Double?
        public let message: String
        public let timestamp: Date

        public enum AnomalyType: String, Sendable {
            case suddenHeartRateChange
            case highHeartRate
            case lowHeartRate
            case lowBloodOxygen
            case irregularHRV
        }

        init(type: AnomalyType, value: Double, previousValue: Double? = nil, message: String) {
            self.type = type
            self.value = value
            self.previousValue = previousValue
            self.message = message
            timestamp = Date()
        }
    }

    public enum HealthKitError: Error {
        case notAvailable
        case authorizationDenied
        case queryFailed(Error)
    }
#endif
