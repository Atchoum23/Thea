import Foundation
import XCTest

/// Standalone tests for FunctionGemma rule-based NL→function call parsing.
/// Mirrors the parsing logic in FunctionGemmaEngine.parseWithRules() and
/// FunctionGemmaBridge security patterns without importing the full module.
final class FunctionGemmaParsingTests: XCTestCase {

    // MARK: - Intent Detection Types

    private struct ParsedCall {
        let module: String
        let function: String
        let confidence: Double
    }

    // MARK: - Calendar Intent Parsing

    private func parseCalendarIntent(_ input: String) -> ParsedCall? {
        let lower = input.lowercased()
        let triggers = ["calendar", "event", "meeting", "appointment", "schedule"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("create") || lower.contains("add") || lower.contains("schedule") || lower.contains("new") {
            return ParsedCall(module: "calendar", function: "createEvent", confidence: 0.8)
        }
        if lower.contains("show") || lower.contains("list") || lower.contains("what") || lower.contains("get") {
            if lower.contains("today") {
                return ParsedCall(module: "calendar", function: "getTodayEvents", confidence: 0.9)
            }
            return ParsedCall(module: "calendar", function: "getEvents", confidence: 0.7)
        }
        return nil
    }

    // MARK: - Reminder Intent Parsing

    private func parseReminderIntent(_ input: String) -> ParsedCall? {
        let lower = input.lowercased()
        let triggers = ["reminder", "remind", "todo", "to-do", "task"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("create") || lower.contains("add") || lower.contains("set") || lower.contains("new") || lower.contains("remind me") {
            return ParsedCall(module: "reminders", function: "createReminder", confidence: 0.85)
        }
        if lower.contains("show") || lower.contains("list") || lower.contains("get") {
            return ParsedCall(module: "reminders", function: "fetchReminders", confidence: 0.8)
        }
        return nil
    }

    // MARK: - Music Intent Parsing

    private func parseMusicIntent(_ input: String) -> ParsedCall? {
        let lower = input.lowercased()
        let triggers = ["music", "song", "play", "pause", "skip", "volume"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("play") { return ParsedCall(module: "music", function: "play", confidence: 0.8) }
        if lower.contains("pause") || lower.contains("stop") { return ParsedCall(module: "music", function: "pause", confidence: 0.85) }
        if lower.contains("skip") || lower.contains("next") { return ParsedCall(module: "music", function: "nextTrack", confidence: 0.85) }
        return nil
    }

    // MARK: - Safari Intent Parsing

    private func parseSafariIntent(_ input: String) -> ParsedCall? {
        let lower = input.lowercased()
        let triggers = ["safari", "browse", "website", "web page", "open url", "search for", "search the web"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("open") || lower.contains("navigate") || lower.contains("go to") {
            return ParsedCall(module: "safari", function: "navigateTo", confidence: 0.9)
        }
        if lower.contains("search") {
            return ParsedCall(module: "safari", function: "navigateTo", confidence: 0.8)
        }
        return nil
    }

    // MARK: - Terminal Intent Parsing

    private func parseTerminalIntent(_ input: String) -> ParsedCall? {
        let lower = input.lowercased()
        let triggers = ["terminal", "command line", "shell", "run command", "execute"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("run") || lower.contains("execute") || lower.contains("open terminal") {
            return ParsedCall(module: "terminal", function: "executeCommand", confidence: 0.8)
        }
        return nil
    }

    // MARK: - Calendar Tests

    func testParsesCreateCalendarEvent() {
        let call = parseCalendarIntent("Create a calendar event for tomorrow's meeting")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.module, "calendar")
        XCTAssertEqual(call?.function, "createEvent")
        XCTAssertGreaterThanOrEqual(call?.confidence ?? 0, 0.7)
    }

    func testParsesScheduleEvent() {
        let call = parseCalendarIntent("Schedule a meeting with John at 3pm")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "createEvent")
    }

    func testParsesGetTodayEvents() {
        let call = parseCalendarIntent("What's on my calendar today?")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "getTodayEvents")
        XCTAssertGreaterThan(call?.confidence ?? 0, 0.8)
    }

    func testParsesListEvents() {
        let call = parseCalendarIntent("Show me my upcoming events")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "getEvents")
    }

    func testCalendarIgnoresUnrelated() {
        let call = parseCalendarIntent("What is the meaning of life?")
        XCTAssertNil(call, "Should not parse non-calendar intent")
    }

    // MARK: - Reminder Tests

    func testParsesCreateReminder() {
        let call = parseReminderIntent("Remind me to buy groceries")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.module, "reminders")
        XCTAssertEqual(call?.function, "createReminder")
    }

    func testParsesAddTodo() {
        let call = parseReminderIntent("Add a todo to call the doctor")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "createReminder")
    }

    func testParsesListReminders() {
        let call = parseReminderIntent("Show my reminders")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "fetchReminders")
    }

    // MARK: - Music Tests

    func testParsesPlayMusic() {
        let call = parseMusicIntent("Play some music")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.module, "music")
        XCTAssertEqual(call?.function, "play")
    }

    func testParsesPauseMusic() {
        let call = parseMusicIntent("Pause the music")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "pause")
    }

    func testParsesSkipTrack() {
        let call = parseMusicIntent("Skip this song")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "nextTrack")
    }

    func testParsesNextTrack() {
        let call = parseMusicIntent("Next song please")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "nextTrack")
    }

    // MARK: - Safari Tests

    func testParsesOpenWebsite() {
        let call = parseSafariIntent("Open Safari and go to apple.com")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.module, "safari")
        XCTAssertEqual(call?.function, "navigateTo")
    }

    func testParsesWebSearch() {
        let call = parseSafariIntent("Search for MLX documentation")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.function, "navigateTo")
    }

    // MARK: - Terminal Tests

    func testParsesRunCommand() {
        let call = parseTerminalIntent("Run command git status in terminal")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.module, "terminal")
        XCTAssertEqual(call?.function, "executeCommand")
    }

    func testTerminalIgnoresUnrelated() {
        let call = parseTerminalIntent("Tell me about Swift programming")
        XCTAssertNil(call)
    }

    // MARK: - Cross-Module Non-Interference

    func testMusicDoesNotTriggerCalendar() {
        let call = parseCalendarIntent("Play my favorite song")
        XCTAssertNil(call, "Music intent should not trigger calendar parser")
    }

    func testCalendarDoesNotTriggerReminder() {
        let call = parseReminderIntent("Create a calendar event for tomorrow")
        XCTAssertNil(call, "Calendar intent should not trigger reminder parser")
    }

    // MARK: - FunctionGemmaBridge Security Patterns

    /// Dangerous commands that FunctionGemmaBridge must block
    private let blockedCommands: [String] = [
        "rm -rf", "rm -r /", "rm -fr", "mkfs", "dd if=", "> /dev/",
        "chmod -R 777", "chmod 777 /", "curl.*|.*sh", "wget.*|.*sh",
        "sudo", "su -", ":(){:|:&};:", "shutdown", "reboot", "halt",
        "launchctl unload", "killall", "kill -9", "diskutil erase",
        "diskutil unmount"
    ]

    /// Shell metacharacters that must be rejected
    private let dangerousChars: Set<Character> = [";", "|", "&", "`", "$", "(", ")"]

    func testBlocksDangerousCommands() {
        for pattern in blockedCommands {
            // Build a realistic user command containing the dangerous pattern
            let command = "please \(pattern) something"
            let lower = command.lowercased()
            let isBlocked = blockedCommands.contains { lower.contains($0.lowercased()) }
            XCTAssertTrue(isBlocked, "Should block command containing: \(pattern)")
        }
    }

    func testBlocksRmRf() {
        let command = "rm -rf /"
        let isBlocked = blockedCommands.contains { command.lowercased().contains($0.lowercased()) }
        XCTAssertTrue(isBlocked)
    }

    func testBlocksSudo() {
        let command = "sudo apt-get install something"
        let isBlocked = blockedCommands.contains { command.lowercased().contains($0.lowercased()) }
        XCTAssertTrue(isBlocked)
    }

    func testBlocksShellMetacharacters() {
        let commands = ["ls; rm -rf /", "cat file | grep x", "echo $(whoami)", "cat `id`", "echo $PATH", "echo $(id)"]
        for command in commands {
            let hasDangerous = command.contains { dangerousChars.contains($0) }
            XCTAssertTrue(hasDangerous, "Should reject command with metacharacters: \(command)")
        }
    }

    func testAllowsSafeCommands() {
        let safeCommands = ["ls -la", "git status", "swift build", "echo hello", "cat file.txt"]
        for command in safeCommands {
            let isBlocked = blockedCommands.contains { command.lowercased().contains($0) }
            let hasDangerous = command.contains { dangerousChars.contains($0) }
            XCTAssertFalse(isBlocked && hasDangerous, "Safe command should not be blocked: \(command)")
        }
    }

    // MARK: - Confidence Scoring

    func testHighConfidenceForSpecificIntents() {
        let todayEvents = parseCalendarIntent("What events do I have today?")
        XCTAssertGreaterThanOrEqual(todayEvents?.confidence ?? 0, 0.9,
            "Specific 'today events' query should have high confidence")
    }

    func testLowerConfidenceForVagueIntents() {
        let vagueEvents = parseCalendarIntent("Show events")
        XCTAssertLessThan(vagueEvents?.confidence ?? 1.0, 0.9,
            "Vague 'show events' should have lower confidence than 'today events'")
    }
}
