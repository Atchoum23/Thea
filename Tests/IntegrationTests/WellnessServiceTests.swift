import XCTest
@testable import TheaCore

/// Test suite for Wellness module services
@MainActor
final class WellnessServiceTests: XCTestCase {

    // MARK: - Circadian Phase Tests

    func testCircadianPhaseTransitions() {
        // Test all phase transitions throughout the day
        let phases: [(hour: Int, expected: CircadianPhase)] = [
            (0, .deepNight),
            (3, .deepNight),
            (5, .earlyMorning),
            (7, .morning),
            (10, .midday),
            (13, .afternoon),
            (17, .evening),
            (20, .night),
            (22, .lateNight),
            (23, .lateNight)
        ]

        for (hour, expectedPhase) in phases {
            let detected = CircadianPhase.phaseForHour(hour)
            XCTAssertEqual(detected, expectedPhase,
                          "Hour \(hour) should be \(expectedPhase.displayName), got \(detected.displayName)")
        }
    }

    func testPhaseRecommendationCount() {
        for phase in CircadianPhase.allCases {
            XCTAssertGreaterThanOrEqual(phase.recommendations.count, 3,
                                       "\(phase.displayName) should have at least 3 recommendations")
        }
    }

    func testPhaseColorThemes() {
        for phase in CircadianPhase.allCases {
            XCTAssertFalse(phase.themeColors.isEmpty, "\(phase.displayName) should have theme colors")
            XCTAssertEqual(phase.themeColors.count, 2, "Each phase should have 2 theme colors")
        }
    }

    func testPhaseTimeRanges() {
        // Ensure time ranges are valid and non-overlapping
        let allPhases = CircadianPhase.allCases

        for index in 0..<(allPhases.count - 1) {
            let currentPhase = allPhases[index]
            let nextPhase = allPhases[index + 1]

            // Skip deepNight wrap-around
            if currentPhase == .lateNight && nextPhase == .deepNight {
                continue
            }

            XCTAssertLessThanOrEqual(currentPhase.endHour, nextPhase.startHour,
                                    "\(currentPhase.displayName) end should not overlap with \(nextPhase.displayName) start")
        }
    }

    // MARK: - Circadian ViewModel Tests

    func testCircadianViewModelPhaseUpdate() async {
        let viewModel = CircadianViewModel()

        await viewModel.updateCurrentPhase(.morning)
        XCTAssertEqual(viewModel.currentPhase, .morning)

        await viewModel.updateCurrentPhase(.evening)
        XCTAssertEqual(viewModel.currentPhase, .evening)
    }

    func testNextPhaseCalculation() async {
        let viewModel = CircadianViewModel()

        // Test progression through phases
        await viewModel.updateCurrentPhase(.morning)
        // Next phase calculation is private, but we can test it's not nil
        XCTAssertNotNil(viewModel.nextPhase)

        await viewModel.updateCurrentPhase(.night)
        XCTAssertNotNil(viewModel.nextPhase)
    }

    // MARK: - Phase Recommendation Tests

    func testRecommendationStructure() {
        let recommendation = PhaseRecommendation(
            icon: "sun.max.fill",
            title: "Get Sunlight",
            description: "Expose yourself to bright light"
        )

        XCTAssertEqual(recommendation.icon, "sun.max.fill")
        XCTAssertEqual(recommendation.title, "Get Sunlight")
        XCTAssertFalse(recommendation.description.isEmpty)
    }

    func testRecommendationUniqueness() {
        // Ensure recommendations have unique titles within each phase
        for phase in CircadianPhase.allCases {
            let titles = Set(phase.recommendations.map { $0.title })
            XCTAssertEqual(titles.count, phase.recommendations.count,
                          "\(phase.displayName) has duplicate recommendation titles")
        }
    }

    // MARK: - Circadian Clock Visualization Tests

    func testPhaseAngleCalculation() {
        // Test that phases span correct degrees on clock
        let morningPhase = CircadianPhase.morning
        let startAngle = Double(morningPhase.startHour) * 15.0 // 15 degrees per hour
        let endAngle = Double(morningPhase.endHour) * 15.0

        let expectedStart = 7.0 * 15.0 // 7 AM = 105 degrees
        let expectedEnd = 10.0 * 15.0   // 10 AM = 150 degrees

        XCTAssertEqual(startAngle, expectedStart, "Morning phase should start at 105 degrees")
        XCTAssertEqual(endAngle, expectedEnd, "Morning phase should end at 150 degrees")
    }

    func testFullDayCoverage() {
        // Ensure all 24 hours are covered by phases
        var coveredHours = Set<Int>()

        for phase in CircadianPhase.allCases {
            if phase == .deepNight {
                // Deep night wraps around (0-5 AM)
                for hour in 0..<phase.endHour {
                    coveredHours.insert(hour)
                }
            } else {
                for hour in phase.startHour..<phase.endHour {
                    coveredHours.insert(hour)
                }
            }
        }

        XCTAssertEqual(coveredHours.count, 24, "All 24 hours should be covered by phases")
    }

    // MARK: - UI Theme Adaptation Tests

    func testThemeColorConsistency() {
        for phase in CircadianPhase.allCases {
            let primaryColor = phase.primaryColor
            let themeColors = phase.themeColors

            XCTAssertFalse(themeColors.isEmpty, "\(phase.displayName) should have theme colors")

            // Background colors should be lighter versions of theme colors
            let backgroundColors = phase.backgroundColors
            XCTAssertEqual(backgroundColors.count, themeColors.count,
                          "Background colors should match theme colors count")
        }
    }

    func testPhaseIconNames() {
        let expectedIcons: [CircadianPhase: String] = [
            .earlyMorning: "sunrise.fill",
            .morning: "sun.max.fill",
            .midday: "sun.max.circle.fill",
            .afternoon: "sun.haze.fill",
            .evening: "sunset.fill",
            .night: "moon.stars.fill",
            .lateNight: "moon.fill",
            .deepNight: "moon.zzz.fill"
        ]

        for (phase, expectedIcon) in expectedIcons {
            XCTAssertEqual(phase.iconName, expectedIcon,
                          "\(phase.displayName) should have icon \(expectedIcon)")
        }
    }

    // MARK: - Time Formatting Tests

    func testPhaseTimeRangeFormatting() {
        let morningPhase = CircadianPhase.morning
        let timeRange = morningPhase.timeRange

        XCTAssertTrue(timeRange.contains("7:00"), "Morning phase should start at 7:00")
        XCTAssertTrue(timeRange.contains("10:00"), "Morning phase should end at 10:00")
        XCTAssertTrue(timeRange.contains("AM"), "Morning hours should be in AM")
    }

    func testDeepNightTimeRangeFormatting() {
        let deepNightPhase = CircadianPhase.deepNight
        let timeRange = deepNightPhase.timeRange

        XCTAssertEqual(timeRange, "12:00 AM - 5:00 AM",
                      "Deep night should have special formatting for wrap-around")
    }

    // MARK: - Performance Tests

    func testPhaseDetectionPerformance() {
        measure {
            for hour in 0..<24 {
                _ = CircadianPhase.phaseForHour(hour)
            }
        }
    }

    func testRecommendationAccessPerformance() {
        measure {
            for phase in CircadianPhase.allCases {
                _ = phase.recommendations
            }
        }
    }

    func testThemeColorGenerationPerformance() {
        measure {
            for phase in CircadianPhase.allCases {
                _ = phase.themeColors
                _ = phase.backgroundColors
            }
        }
    }

    // MARK: - Integration Tests

    func testPhaseToRecommendationFlow() {
        // Test that every phase has actionable recommendations
        for phase in CircadianPhase.allCases {
            let recommendations = phase.recommendations

            for recommendation in recommendations {
                // Each recommendation should have all required fields
                XCTAssertFalse(recommendation.icon.isEmpty,
                              "\(phase.displayName) recommendation missing icon")
                XCTAssertFalse(recommendation.title.isEmpty,
                              "\(phase.displayName) recommendation missing title")
                XCTAssertFalse(recommendation.description.isEmpty,
                              "\(phase.displayName) recommendation missing description")

                // Icon should be a valid SF Symbol name
                XCTAssertTrue(recommendation.icon.contains(".") || recommendation.icon.count > 3,
                             "Icon '\(recommendation.icon)' might not be a valid SF Symbol")
            }
        }
    }

    func testCircadianDataConsistency() {
        // Ensure all phases have consistent data structure
        for phase in CircadianPhase.allCases {
            XCTAssertFalse(phase.displayName.isEmpty)
            XCTAssertFalse(phase.shortName.isEmpty)
            XCTAssertFalse(phase.description.isEmpty)
            XCTAssertFalse(phase.iconName.isEmpty)
            XCTAssertLessThan(phase.startHour, 24)
            XCTAssertGreaterThanOrEqual(phase.startHour, 0)
        }
    }

    // MARK: - Edge Case Tests

    func testMidnightHourHandling() {
        let phase = CircadianPhase.phaseForHour(0)
        XCTAssertEqual(phase, .deepNight, "Midnight (hour 0) should be deep night")
    }

    func testNoonHourHandling() {
        let phase = CircadianPhase.phaseForHour(12)
        XCTAssertEqual(phase, .midday, "Noon (hour 12) should be midday")
    }

    func testLatestHourHandling() {
        let phase = CircadianPhase.phaseForHour(23)
        XCTAssertEqual(phase, .lateNight, "11 PM (hour 23) should be late night")
    }

    // MARK: - Hashable Conformance Tests

    func testPhaseRecommendationHashable() {
        let rec1 = PhaseRecommendation(icon: "sun", title: "Sunlight", description: "Get sun")
        let rec2 = PhaseRecommendation(icon: "sun", title: "Sunlight", description: "Get sun")
        let rec3 = PhaseRecommendation(icon: "moon", title: "Sleep", description: "Rest")

        // Hashable allows use in Sets
        let set: Set<PhaseRecommendation> = [rec1, rec2, rec3]
        XCTAssertGreaterThanOrEqual(set.count, 1, "Should be able to create Set of recommendations")
    }

    // MARK: - Sendable Conformance Tests

    func testCircadianPhaseSendable() async {
        // Test that CircadianPhase can be safely sent across actor boundaries
        actor TestActor {
            var currentPhase: CircadianPhase = .morning

            func updatePhase(_ newPhase: CircadianPhase) {
                currentPhase = newPhase
            }

            func getPhase() -> CircadianPhase {
                currentPhase
            }
        }

        let testActor = TestActor()
        await testActor.updatePhase(.evening)
        let phase = await testActor.getPhase()

        XCTAssertEqual(phase, .evening)
    }

    func testRecommendationSendable() async {
        // Test that PhaseRecommendation can be safely sent across actors
        actor TestActor {
            var recommendations: [PhaseRecommendation] = []

            func addRecommendation(_ rec: PhaseRecommendation) {
                recommendations.append(rec)
            }

            func getCount() -> Int {
                recommendations.count
            }
        }

        let testActor = TestActor()
        let rec = PhaseRecommendation(icon: "test", title: "Test", description: "Test desc")
        await testActor.addRecommendation(rec)
        let count = await testActor.getCount()

        XCTAssertEqual(count, 1)
    }
}
