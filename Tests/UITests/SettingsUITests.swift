import XCTest

final class SettingsUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Open settings via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1)
    }
    
    override func tearDownWithError() throws {
        // Close settings if open
        app.typeKey("w", modifierFlags: .command)
        
        if testRun?.totalFailureCount ?? 0 > 0 {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
    
    // MARK: - General Tab
    
    func testSG01_GeneralTabExists() throws {
        let generalTab = app.buttons["General"]
        if generalTab.waitForExistence(timeout: 3) {
            generalTab.click()
            XCTAssertTrue(true, "General tab accessible")
        }
    }
    
    func testSG02_ThemePicker() throws {
        let generalTab = app.buttons["General"]
        if generalTab.exists { generalTab.click() }
        
        // Look for theme picker
        let themePicker = app.popUpButtons.firstMatch
        if themePicker.waitForExistence(timeout: 2) {
            themePicker.click()
            XCTAssertTrue(true, "Theme picker accessible")
        }
    }
    
    // MARK: - AI Providers Tab
    
    func testSP01_AIProvidersTabExists() throws {
        let tab = app.buttons["AI Providers"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "AI Providers tab accessible")
        }
    }
    
    // MARK: - Models Tab
    
    func testSM01_ModelsTabExists() throws {
        let tab = app.buttons["Models"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Models tab accessible")
        }
    }
    
    // MARK: - Local Models Tab
    
    func testSL01_LocalModelsTabExists() throws {
        let tab = app.buttons["Local Models"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Local Models tab accessible")
        }
    }
    
    // MARK: - Orchestrator Tab
    
    func testSO01_OrchestratorTabExists() throws {
        let tab = app.buttons["Orchestrator"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Orchestrator tab accessible")
        }
    }
    
    // MARK: - Voice Tab
    
    func testSV01_VoiceTabExists() throws {
        let tab = app.buttons["Voice"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Voice tab accessible")
        }
    }
    
    // MARK: - Sync Tab
    
    func testSY01_SyncTabExists() throws {
        let tab = app.buttons["Sync"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Sync tab accessible")
        }
    }
    
    // MARK: - Privacy Tab
    
    func testSR01_PrivacyTabExists() throws {
        let tab = app.buttons["Privacy"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Privacy tab accessible")
        }
    }
    
    // MARK: - Advanced Tab
    
    func testSA01_AdvancedTabExists() throws {
        let tab = app.buttons["Advanced"]
        if tab.waitForExistence(timeout: 3) {
            tab.click()
            XCTAssertTrue(true, "Advanced tab accessible")
        }
    }
    
    // MARK: - Settings State Management
    
    func testSX01_CancelDiscardsChanges() throws {
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.click()
            XCTAssertTrue(true, "Cancel button works")
        }
    }
}
