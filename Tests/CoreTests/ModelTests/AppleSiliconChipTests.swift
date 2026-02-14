// AppleSiliconChipTests.swift
// Tests for AppleSiliconChip enum: generation, local model support, size recommendations

import Foundation
import XCTest

// MARK: - Mirrored Type

private enum AppleSiliconChip: String, Codable, CaseIterable {
    case m1 = "M1"
    case m1Pro = "M1 Pro"
    case m1Max = "M1 Max"
    case m1Ultra = "M1 Ultra"
    case m2 = "M2"
    case m2Pro = "M2 Pro"
    case m2Max = "M2 Max"
    case m2Ultra = "M2 Ultra"
    case m3 = "M3"
    case m3Pro = "M3 Pro"
    case m3Max = "M3 Max"
    case m3Ultra = "M3 Ultra"
    case m4 = "M4"
    case m4Pro = "M4 Pro"
    case m4Max = "M4 Max"
    case m4Ultra = "M4 Ultra"
    case a14 = "A14 Bionic"
    case a15 = "A15 Bionic"
    case a16 = "A16 Bionic"
    case a17Pro = "A17 Pro"
    case a18 = "A18"
    case a18Pro = "A18 Pro"
    case s9 = "S9"
    case s10 = "S10"
    case unknown = "Unknown"

    var displayName: String { rawValue }

    var generation: Int {
        switch self {
        case .m1, .m1Pro, .m1Max, .m1Ultra: 1
        case .m2, .m2Pro, .m2Max, .m2Ultra: 2
        case .m3, .m3Pro, .m3Max, .m3Ultra: 3
        case .m4, .m4Pro, .m4Max, .m4Ultra: 4
        case .a14, .a15, .a16: 0
        case .a17Pro, .a18, .a18Pro: 0
        case .s9, .s10: 0
        case .unknown: 0
        }
    }

    var supportsLocalModels: Bool {
        switch self {
        case .m1, .m1Pro, .m1Max, .m1Ultra,
             .m2, .m2Pro, .m2Max, .m2Ultra,
             .m3, .m3Pro, .m3Max, .m3Ultra,
             .m4, .m4Pro, .m4Max, .m4Ultra:
            true
        case .a17Pro, .a18, .a18Pro:
            true
        case .a14, .a15, .a16:
            false
        case .s9, .s10:
            false
        case .unknown:
            false
        }
    }

    var maxRecommendedModelSizeGB: Double {
        switch self {
        case .m4Ultra: 100.0
        case .m4Max, .m3Ultra: 50.0
        case .m4Pro, .m3Max, .m2Ultra: 30.0
        case .m4, .m3Pro, .m2Max, .m1Ultra: 20.0
        case .m3, .m2Pro, .m1Max: 15.0
        case .m2, .m1Pro: 10.0
        case .m1: 8.0
        case .a18Pro, .a18: 4.0
        case .a17Pro: 3.0
        case .a14, .a15, .a16: 1.0
        case .s9, .s10: 0.0
        case .unknown: 4.0
        }
    }
}

// MARK: - Tests

final class AppleSiliconChipTests: XCTestCase {

    func testTotalCaseCount() {
        XCTAssertEqual(AppleSiliconChip.allCases.count, 25)
    }

    func testDisplayNameEqualsRawValue() {
        for chip in AppleSiliconChip.allCases {
            XCTAssertEqual(chip.displayName, chip.rawValue)
        }
    }

    func testUniqueRawValues() {
        let rawValues = AppleSiliconChip.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "All raw values must be unique")
    }

    // MARK: - Generation Tests

    func testM1Generation() {
        for chip in [AppleSiliconChip.m1, .m1Pro, .m1Max, .m1Ultra] {
            XCTAssertEqual(chip.generation, 1, "\(chip.rawValue) should be gen 1")
        }
    }

    func testM2Generation() {
        for chip in [AppleSiliconChip.m2, .m2Pro, .m2Max, .m2Ultra] {
            XCTAssertEqual(chip.generation, 2, "\(chip.rawValue) should be gen 2")
        }
    }

    func testM3Generation() {
        for chip in [AppleSiliconChip.m3, .m3Pro, .m3Max, .m3Ultra] {
            XCTAssertEqual(chip.generation, 3, "\(chip.rawValue) should be gen 3")
        }
    }

    func testM4Generation() {
        for chip in [AppleSiliconChip.m4, .m4Pro, .m4Max, .m4Ultra] {
            XCTAssertEqual(chip.generation, 4, "\(chip.rawValue) should be gen 4")
        }
    }

    func testASeriesGenerationIsZero() {
        for chip in [AppleSiliconChip.a14, .a15, .a16, .a17Pro, .a18, .a18Pro] {
            XCTAssertEqual(chip.generation, 0, "\(chip.rawValue) A-series should have gen 0")
        }
    }

    func testSSeriesGenerationIsZero() {
        for chip in [AppleSiliconChip.s9, .s10] {
            XCTAssertEqual(chip.generation, 0, "\(chip.rawValue) S-series should have gen 0")
        }
    }

    func testUnknownGenerationIsZero() {
        XCTAssertEqual(AppleSiliconChip.unknown.generation, 0)
    }

    // MARK: - Local Model Support Tests

    func testAllMSeriesSupportLocalModels() {
        let mChips: [AppleSiliconChip] = [
            .m1, .m1Pro, .m1Max, .m1Ultra,
            .m2, .m2Pro, .m2Max, .m2Ultra,
            .m3, .m3Pro, .m3Max, .m3Ultra,
            .m4, .m4Pro, .m4Max, .m4Ultra
        ]
        for chip in mChips {
            XCTAssertTrue(chip.supportsLocalModels, "\(chip.rawValue) should support local models")
        }
    }

    func testNewASeriesSupportsLocalModels() {
        for chip in [AppleSiliconChip.a17Pro, .a18, .a18Pro] {
            XCTAssertTrue(chip.supportsLocalModels, "\(chip.rawValue) should support local models")
        }
    }

    func testOldASeriesDoesNotSupportLocalModels() {
        for chip in [AppleSiliconChip.a14, .a15, .a16] {
            XCTAssertFalse(chip.supportsLocalModels, "\(chip.rawValue) should not support local models")
        }
    }

    func testSSeriesDoesNotSupportLocalModels() {
        for chip in [AppleSiliconChip.s9, .s10] {
            XCTAssertFalse(chip.supportsLocalModels, "\(chip.rawValue) should not support local models")
        }
    }

    func testUnknownDoesNotSupportLocalModels() {
        XCTAssertFalse(AppleSiliconChip.unknown.supportsLocalModels)
    }

    // MARK: - Model Size Recommendations

    func testM4UltraHasLargestModelSize() {
        let maxSize = AppleSiliconChip.allCases.map(\.maxRecommendedModelSizeGB).max()!
        XCTAssertEqual(AppleSiliconChip.m4Ultra.maxRecommendedModelSizeGB, maxSize)
        XCTAssertEqual(maxSize, 100.0)
    }

    func testUltraChipsAreAtLeast20GB() {
        let ultras: [AppleSiliconChip] = [.m1Ultra, .m2Ultra, .m3Ultra, .m4Ultra]
        for chip in ultras {
            XCTAssertGreaterThanOrEqual(
                chip.maxRecommendedModelSizeGB, 20.0,
                "\(chip.rawValue) Ultra should support at least 20GB models"
            )
        }
    }

    func testHigherGenerationAllowsLargerOrEqualModels() {
        // Within same tier, newer gen should allow >= model size
        XCTAssertGreaterThanOrEqual(
            AppleSiliconChip.m4.maxRecommendedModelSizeGB,
            AppleSiliconChip.m1.maxRecommendedModelSizeGB
        )
        XCTAssertGreaterThanOrEqual(
            AppleSiliconChip.m4Ultra.maxRecommendedModelSizeGB,
            AppleSiliconChip.m1Ultra.maxRecommendedModelSizeGB
        )
    }

    func testSSeriesHasZeroModelSize() {
        for chip in [AppleSiliconChip.s9, .s10] {
            XCTAssertEqual(chip.maxRecommendedModelSizeGB, 0.0,
                           "\(chip.rawValue) should have 0 model size")
        }
    }

    func testOldASeriesHasMinimalModelSize() {
        for chip in [AppleSiliconChip.a14, .a15, .a16] {
            XCTAssertEqual(chip.maxRecommendedModelSizeGB, 1.0,
                           "\(chip.rawValue) should max at 1GB")
        }
    }

    func testModelSizeAlwaysNonNegative() {
        for chip in AppleSiliconChip.allCases {
            XCTAssertGreaterThanOrEqual(
                chip.maxRecommendedModelSizeGB, 0.0,
                "\(chip.rawValue) model size must be >= 0"
            )
        }
    }

    // MARK: - Consistency Checks

    func testChipsThatSupportModelsHavePositiveSize() {
        for chip in AppleSiliconChip.allCases where chip.supportsLocalModels {
            XCTAssertGreaterThan(
                chip.maxRecommendedModelSizeGB, 0.0,
                "\(chip.rawValue) supports models but has 0 size"
            )
        }
    }

    func testChipsWithZeroSizeDontSupportModels() {
        for chip in AppleSiliconChip.allCases where chip.maxRecommendedModelSizeGB == 0.0 {
            XCTAssertFalse(
                chip.supportsLocalModels,
                "\(chip.rawValue) has 0GB size but claims model support"
            )
        }
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        for chip in AppleSiliconChip.allCases {
            let data = try JSONEncoder().encode(chip)
            let decoded = try JSONDecoder().decode(AppleSiliconChip.self, from: data)
            XCTAssertEqual(decoded, chip)
        }
    }

    func testDecodableFromRawValue() throws {
        let json = Data("\"M3 Ultra\"".utf8)
        let decoded = try JSONDecoder().decode(AppleSiliconChip.self, from: json)
        XCTAssertEqual(decoded, .m3Ultra)
    }
}
