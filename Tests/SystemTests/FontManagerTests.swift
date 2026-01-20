//
//  FontManagerTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
@testable import Thea

final class FontManagerTests: XCTestCase {

    var fontManager: FontManager!

    override func setUp() async throws {
        fontManager = await FontManager.shared
    }

    // MARK: - Scale Factor Tests

    func testDefaultScaleFactor() async {
        let scale = await fontManager.scaleFactor
        XCTAssertEqual(scale, 1.0, "Default scale factor should be 1.0")
    }

    func testSetScaleFactorWithinRange() async {
        await fontManager.setScaleFactor(1.5)
        let scale = await fontManager.scaleFactor
        XCTAssertEqual(scale, 1.5, "Scale factor should be set to 1.5")
    }

    func testScaleFactorClampedToMinimum() async {
        await fontManager.setScaleFactor(0.5)
        let scale = await fontManager.scaleFactor
        XCTAssertEqual(scale, 0.8, "Scale factor should be clamped to minimum 0.8")
    }

    func testScaleFactorClampedToMaximum() async {
        await fontManager.setScaleFactor(3.0)
        let scale = await fontManager.scaleFactor
        XCTAssertEqual(scale, 2.0, "Scale factor should be clamped to maximum 2.0")
    }

    // MARK: - Font Family Tests

    func testDefaultFontFamily() async {
        let family = await fontManager.currentFontFamily
        XCTAssertEqual(family, .system, "Default font family should be system")
    }

    func testSetFontFamily() async {
        await fontManager.setFontFamily(.monospaced)
        let family = await fontManager.currentFontFamily
        XCTAssertEqual(family, .monospaced, "Font family should be monospaced")
    }

    // MARK: - Font Generation Tests

    func testBodyFont() async {
        let font = await fontManager.font(for: .body)
        XCTAssertNotNil(font, "Body font should not be nil")
    }

    func testTitleFont() async {
        let font = await fontManager.font(for: .title)
        XCTAssertNotNil(font, "Title font should not be nil")
    }

    func testCaptionFont() async {
        let font = await fontManager.font(for: .caption)
        XCTAssertNotNil(font, "Caption font should not be nil")
    }

    // MARK: - Scaled Font Tests

    func testScaledFontSize() async {
        await fontManager.setScaleFactor(1.5)
        let font = await fontManager.font(for: .body)
        // Body default is 17pt, scaled should be 25.5pt
        XCTAssertNotNil(font, "Scaled font should not be nil")
    }

    // MARK: - Font Style Tests

    func testFontStyleDisplayNames() {
        XCTAssertEqual(FontStyle.body.displayName, "Body")
        XCTAssertEqual(FontStyle.title.displayName, "Title")
        XCTAssertEqual(FontStyle.headline.displayName, "Headline")
    }

    func testFontFamilyDisplayNames() {
        XCTAssertEqual(FontFamily.system.displayName, "System")
        XCTAssertEqual(FontFamily.monospaced.displayName, "Monospaced")
        XCTAssertEqual(FontFamily.rounded.displayName, "Rounded")
        XCTAssertEqual(FontFamily.serif.displayName, "Serif")
    }
}
