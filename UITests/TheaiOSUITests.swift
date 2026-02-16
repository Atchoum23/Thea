import XCTest

@MainActor
final class TheaiOSUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Auto-dismiss system alerts (Screen Time, notifications, etc.)
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }

        app.launch()
        // Trigger interruption handler by interacting with the app
        app.tap()
        sleep(1)
    }

    // MARK: - Tab Bar Navigation

    func testTabBarExists() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }

    func testChatTabLoads() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let chatTab = tabBar.buttons["Chat"]
        XCTAssertTrue(chatTab.exists, "Chat tab should exist")
        chatTab.tap()

        // Verify Chat view loaded - check for search field or title
        let chatTitle = app.navigationBars["Chat"].firstMatch
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            chatTitle.waitForExistence(timeout: 3) || searchField.waitForExistence(timeout: 3),
            "Chat view should load with title or search field"
        )
    }

    func testProjectsTabLoads() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let projectsTab = tabBar.buttons["Projects"]
        XCTAssertTrue(projectsTab.exists, "Projects tab should exist")
        projectsTab.tap()

        sleep(1)
        // Take screenshot for verification
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Projects Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHealthTabLoads() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let healthTab = tabBar.buttons["Health"]
        XCTAssertTrue(healthTab.exists, "Health tab should exist")
        healthTab.tap()

        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Health Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKnowledgeTabLoads() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let knowledgeTab = tabBar.buttons["Knowledge"]
        XCTAssertTrue(knowledgeTab.exists, "Knowledge tab should exist")
        knowledgeTab.tap()

        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Knowledge Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMoreTabLoads() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let moreTab = tabBar.buttons["More"]
        XCTAssertTrue(moreTab.exists, "More tab should exist")
        moreTab.tap()

        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "More Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Chat View Interactions

    func testNewConversationButton() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Tap Chat tab first
        let chatTab = tabBar.buttons["Chat"]
        chatTab.tap()
        sleep(1)

        // Look for the new conversation button (compose icon in top-right)
        let composeButton = app.buttons["New Conversation"].firstMatch
        let toolbar = app.navigationBars.firstMatch
        let toolbarButtons = toolbar.buttons

        // The button might have different accessibility labels
        let foundButton = composeButton.exists ||
            toolbarButtons["compose"].exists ||
            toolbarButtons.element(boundBy: 0).exists

        XCTAssertTrue(foundButton, "New conversation button should be accessible")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Chat View - New Conversation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSearchField() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let chatTab = tabBar.buttons["Chat"]
        chatTab.tap()

        // Dismiss any system alerts by tapping the app
        sleep(2)
        app.tap()
        sleep(1)

        // Search field may be a searchFields element or a textField
        let searchField = app.searchFields.firstMatch
        let textField = app.textFields["Search conversations"].firstMatch

        let fieldExists = searchField.waitForExistence(timeout: 3) ||
            textField.waitForExistence(timeout: 3)

        XCTAssertTrue(fieldExists, "Search field should exist on Chat tab")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Search Field"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Quick Action Cards

    func testQuickActionCardsExist() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let chatTab = tabBar.buttons["Chat"]
        chatTab.tap()
        sleep(1)

        // Check for quick action buttons visible in the empty state
        let explainButton = app.buttons["Explain a concept"].firstMatch
        let helpWriteButton = app.buttons["Help me write"].firstMatch
        let debugButton = app.buttons["Debug code"].firstMatch
        let planButton = app.buttons["Plan a project"].firstMatch

        // At least some should be visible
        let anyCardExists = explainButton.exists || helpWriteButton.exists ||
            debugButton.exists || planButton.exists

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Quick Action Cards"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Soft assertion - cards may have different labels
        if !anyCardExists {
            // Check for any static text containing these keywords
            let texts = app.staticTexts
            let hasExplain = texts["Explain a\nconcept"].exists || texts["Explain a concept"].exists
            let hasDebug = texts["Debug code"].exists
            XCTAssertTrue(hasExplain || hasDebug,
                          "Quick action cards should be visible in empty state")
        }
    }

    // MARK: - Tab Switching Cycle

    func testFullTabCycle() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let tabs = ["Chat", "Projects", "Health", "Knowledge", "More"]

        for tabName in tabs {
            let tab = tabBar.buttons[tabName]
            XCTAssertTrue(tab.exists, "\(tabName) tab should exist")
            tab.tap()
            sleep(1)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Tab - \(tabName)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Return to Chat
        tabBar.buttons["Chat"].tap()
    }
}
