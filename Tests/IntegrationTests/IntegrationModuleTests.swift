@testable import TheaCore
import XCTest

/// Test suite for Integration Coordinator and module management
@MainActor
final class IntegrationModuleTests: XCTestCase {
    // MARK: - Integration Coordinator Tests

    func testCoordinatorInitialization() async {
        let coordinator = IntegrationCoordinator.shared

        XCTAssertFalse(coordinator.isInitialized, "Coordinator should not be initialized initially")
        XCTAssertTrue(coordinator.activeModules.isEmpty, "No modules should be active initially")
    }

    func testModuleEnabling() async {
        let coordinator = IntegrationCoordinator.shared

        await coordinator.enableModule(.health)

        XCTAssertTrue(coordinator.isModuleActive(.health), "Health module should be active")
        XCTAssertEqual(coordinator.getModuleStatus(.health), .active, "Health module status should be active")
    }

    func testModuleDisabling() async {
        let coordinator = IntegrationCoordinator.shared

        await coordinator.enableModule(.nutrition)
        XCTAssertTrue(coordinator.isModuleActive(.nutrition))

        await coordinator.disableModule(.nutrition)
        XCTAssertFalse(coordinator.isModuleActive(.nutrition), "Nutrition module should be disabled")
    }

    func testMultipleModuleActivation() async {
        let coordinator = IntegrationCoordinator.shared

        await coordinator.enableModule(.health)
        await coordinator.enableModule(.wellness)
        await coordinator.enableModule(.cognitive)

        XCTAssertEqual(coordinator.getActiveModuleCount(), 3, "Should have 3 active modules")
        XCTAssertTrue(coordinator.activeModules.contains(.health))
        XCTAssertTrue(coordinator.activeModules.contains(.wellness))
        XCTAssertTrue(coordinator.activeModules.contains(.cognitive))
    }

    // MARK: - Integration Utilities Tests

    func testDateExtensions() {
        let testDate = Date()

        let startOfDay = testDate.startOfDay
        XCTAssertEqual(Calendar.current.component(.hour, from: startOfDay), 0)
        XCTAssertEqual(Calendar.current.component(.minute, from: startOfDay), 0)

        let threeDaysAgo = testDate.daysAgo(3)
        let daysDifference = testDate.daysBetween(threeDaysAgo)
        XCTAssertEqual(daysDifference, 3)

        XCTAssertTrue(testDate.isToday)
        XCTAssertTrue(testDate.isWithinLast(days: 1))
        XCTAssertFalse(threeDaysAgo.isToday)
    }

    func testNumberFormatting() {
        let number: Double = 1_234.5678

        XCTAssertEqual(number.formatted(decimals: 2), "1234.57")
        XCTAssertEqual(number.formattedAsPercentage(decimals: 1), "1234.6%")
        XCTAssertEqual(number.rounded(toPlaces: 2), 1_234.57)

        let integer = 1_234_567
        XCTAssertEqual(integer.formattedWithSeparators, "1,234,567")
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatter.formatMinutes(90), "1h 30m")
        XCTAssertEqual(DurationFormatter.formatMinutes(60), "1h")
        XCTAssertEqual(DurationFormatter.formatMinutes(45), "45m")

        XCTAssertEqual(DurationFormatter.formatSeconds(125), "2m 5s")
        XCTAssertEqual(DurationFormatter.formatSeconds(60), "1m")
        XCTAssertEqual(DurationFormatter.formatSeconds(30), "30s")
    }

    func testStatistics() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]

        XCTAssertEqual(Statistics.mean(values), 3.0)
        XCTAssertEqual(Statistics.median(values), 3.0)

        let stdDev = Statistics.standardDeviation(values)
        XCTAssertGreaterThan(stdDev, 0)

        let percentile75 = Statistics.percentile(values, percentile: 75)
        XCTAssertEqual(percentile75, 4.0)

        let (min, max) = Statistics.range(values)
        XCTAssertEqual(min, 1.0)
        XCTAssertEqual(max, 5.0)
    }

    func testValidation() {
        XCTAssertTrue(Validator.isValidEmail("test@example.com"))
        XCTAssertFalse(Validator.isValidEmail("invalid-email"))

        XCTAssertTrue(Validator.isValidPhone("1234567890"))
        XCTAssertTrue(Validator.isValidPhone("(123) 456-7890"))
        XCTAssertFalse(Validator.isValidPhone("123"))

        XCTAssertTrue(Validator.isInRange(5, min: 1, max: 10))
        XCTAssertFalse(Validator.isInRange(15, min: 1, max: 10))

        XCTAssertTrue(Validator.isNonEmpty("Hello"))
        XCTAssertFalse(Validator.isNonEmpty("   "))
    }

    func testTrendAnalyzer() {
        let increasingValues = [10.0, 15.0, 20.0, 25.0, 30.0]
        let trend = TrendAnalyzer.analyzeTrend(increasingValues)
        XCTAssertEqual(trend, .improving)

        let decreasingValues = [30.0, 25.0, 20.0, 15.0, 10.0]
        let declineTrend = TrendAnalyzer.analyzeTrend(decreasingValues)
        XCTAssertEqual(declineTrend, .declining)

        let stableValues = [20.0, 21.0, 20.5, 20.2, 20.1]
        let stableTrend = TrendAnalyzer.analyzeTrend(stableValues)
        XCTAssertEqual(stableTrend, .stable)
    }

    func testPercentageChange() {
        let change = TrendAnalyzer.percentageChange(from: 100, to: 150)
        XCTAssertEqual(change, 50.0)

        let decrease = TrendAnalyzer.percentageChange(from: 200, to: 150)
        XCTAssertEqual(decrease, -25.0)
    }

    func testAnomalyDetection() {
        let values = [10.0, 12.0, 11.0, 13.0, 100.0, 12.0, 11.0] // 100 is anomaly
        let anomalies = TrendAnalyzer.detectAnomalies(values, threshold: 2.0)

        XCTAssertEqual(anomalies.count, 1)
        XCTAssertEqual(anomalies.first, 4) // Index of anomalous value
    }

    // MARK: - Module Enum Tests

    func testModuleEnumeration() {
        XCTAssertEqual(IntegrationModule.allCases.count, 9, "Should have 9 modules")

        let modules: Set<IntegrationModule> = [.health, .wellness, .cognitive, .financial, .career, .assessment, .nutrition, .display, .income]
        XCTAssertEqual(modules.count, 9, "All modules should be unique")
    }

    func testModuleProperties() {
        for module in IntegrationModule.allCases {
            XCTAssertFalse(module.rawValue.isEmpty, "\(module) should have a raw value")
            XCTAssertFalse(module.icon.isEmpty, "\(module) should have an icon")
            // Color property exists (no assertion needed, just checking it doesn't crash)
            _ = module.color
        }
    }

    // MARK: - Health Check Tests

    func testHealthCheckReport() async {
        let coordinator = IntegrationCoordinator.shared

        await coordinator.enableModule(.health)
        await coordinator.enableModule(.wellness)

        let report = await coordinator.performHealthCheck()

        XCTAssertGreaterThanOrEqual(report.activeModules, 2)
        XCTAssertEqual(report.totalModules, 9)
        XCTAssertFalse(report.moduleReports.isEmpty)
    }

    // MARK: - Caching Tests

    func testCacheManager() async {
        let cache = CacheManager<String, Int>(maxAge: 1.0) // 1 second max age

        await cache.set("key1", value: 42)

        let value = await cache.get("key1")
        XCTAssertEqual(value, 42)

        // Wait for expiration
        try? await Task.sleep(for: .seconds(1.5))

        let expiredValue = await cache.get("key1")
        XCTAssertNil(expiredValue, "Value should be expired")
    }

    func testCacheClear() async {
        let cache = CacheManager<String, String>(maxAge: 300)

        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")

        await cache.clear()

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")

        XCTAssertNil(value1)
        XCTAssertNil(value2)
    }

    // MARK: - Debouncer Tests

    func testDebouncer() async {
        let debouncer = Debouncer(duration: 0.3)
        var executionCount = 0

        // Rapid calls
        await debouncer.debounce {
            executionCount += 1
        }
        await debouncer.debounce {
            executionCount += 1
        }
        await debouncer.debounce {
            executionCount += 1
        }

        // Wait for debounce duration
        try? await Task.sleep(for: .seconds(0.5))

        // Should have executed only once
        XCTAssertEqual(executionCount, 1, "Debouncer should execute only once")
    }

    // MARK: - Data Export Tests

    func testCSVExport() {
        struct TestItem {
            let name: String
            let value: Int
        }

        let items = [
            TestItem(name: "Item 1", value: 100),
            TestItem(name: "Item 2", value: 200)
        ]

        let csv = DataExporter.toCSV(items, headers: ["Name", "Value"]) { item in
            [item.name, "\(item.value)"]
        }

        XCTAssertTrue(csv.contains("Name,Value"))
        XCTAssertTrue(csv.contains("Item 1,100"))
        XCTAssertTrue(csv.contains("Item 2,200"))
    }

    func testCSVEscaping() {
        struct TestItem: Codable {
            let field: String
        }

        let items = [TestItem(field: "Value with, comma")]

        let csv = DataExporter.toCSV(items, headers: ["Field"]) { item in
            [item.field]
        }

        XCTAssertTrue(csv.contains("\"Value with, comma\""), "CSV should escape commas")
    }

    // MARK: - Performance Tests

    func testStatisticsPerformance() {
        let largeDataset = (0..<10_000).map { Double($0) }

        measure {
            _ = Statistics.mean(largeDataset)
            _ = Statistics.median(largeDataset)
            _ = Statistics.standardDeviation(largeDataset)
        }
    }

    func testTrendAnalysisPerformance() {
        let largeDataset = (0..<1_000).map { Double($0) }

        measure {
            _ = TrendAnalyzer.analyzeTrend(largeDataset)
        }
    }

    // MARK: - Edge Cases

    func testEmptyArrayStatistics() {
        let empty: [Double] = []

        XCTAssertEqual(Statistics.mean(empty), 0)
        XCTAssertEqual(Statistics.median(empty), 0)
        XCTAssertEqual(Statistics.standardDeviation(empty), 0)
    }

    func testSingleValueStatistics() {
        let single = [42.0]

        XCTAssertEqual(Statistics.mean(single), 42.0)
        XCTAssertEqual(Statistics.median(single), 42.0)
    }

    func testZeroPercentileChange() {
        let change = TrendAnalyzer.percentageChange(from: 0, to: 100)
        XCTAssertEqual(change, 0, "Percentage change from zero should be zero")
    }
}
