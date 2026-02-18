// THEAMCPServer+ToolExecution.swift
// Thea V2
//
// Tool execution router and implementations for the MCP server
// Extracted from THEAMCPServer.swift

import Foundation

#if os(macOS)

// MARK: - Tool Execution

extension THEAMCPServer {
    func executeTool(name: String, arguments: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        switch name {
        case "thea_execute_command":
            return try await executeCommand(arguments)
        case "thea_read_file":
            return try await readFile(arguments)
        case "thea_write_file":
            return try await writeFile(arguments)
        case "thea_list_directory":
            return try await listDirectory(arguments)
        case "thea_search_contacts":
            return try await searchContacts(arguments)
        case "thea_get_reminders":
            return try await getReminders(arguments)
        case "thea_create_reminder":
            return try await createReminder(arguments)
        case "thea_search_notes":
            return try await searchNotes(arguments)
        case "thea_create_note":
            return try await createNote(arguments)
        case "thea_search_location":
            return try await searchLocation(arguments)
        case "thea_get_directions":
            return try await getDirections(arguments)
        case "thea_run_shortcut":
            return try await runShortcut(arguments)
        case "thea_speak":
            return try await speak(arguments)
        default:
            throw THEAMCPToolError.unknownTool(name)
        }
    }
}

// MARK: - Tool Implementations

extension THEAMCPServer {
    func executeCommand(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let command = args["command"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        var result = output
        if !error.isEmpty {
            result += "\nStderr: \(error)"
        }
        result += "\nExit code: \(process.terminationStatus)"

        return [.text(result)]
    }

    func readFile(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let path = args["path"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("path")
        }

        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        return [.text(content)]
    }

    func writeFile(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let path = args["path"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("path")
        }
        guard let content = args["content"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("content")
        }

        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return [.text("Successfully wrote \(content.count) characters to \(path)")]
    }

    func listDirectory(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let path = args["path"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("path")
        }

        let url = URL(fileURLWithPath: path)
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])

        var listing = ""
        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir: Bool
            do {
                isDir = try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
            } catch {
                isDir = false
            }
            listing += "\(isDir ? "\u{1F4C1}" : "\u{1F4C4}") \(item.lastPathComponent)\n"
        }

        return [.text(listing)]
    }

    func searchContacts(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let query = args["query"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("query")
        }

        let criteria = ContactSearchCriteria(nameQuery: query)
        let contacts = try await ContactsIntegration.shared.searchContacts(criteria: criteria)
        var result = "Found \(contacts.count) contacts:\n"
        for contact in contacts.prefix(10) {
            result += "- \(contact.fullName)"
            if let email = contact.emailAddresses.first {
                result += " (\(email.value))"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    func getReminders(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        let includeCompleted = args["completed"]?.boolValue ?? false

        let criteria = ReminderSearchCriteria(
            isCompleted: includeCompleted ? nil : false
        )
        let reminders = try await RemindersIntegration.shared.fetchReminders(criteria: criteria)

        var result = "Found \(reminders.count) reminders:\n"
        for reminder in reminders.prefix(20) {
            let status = reminder.isCompleted ? "\u{2705}" : "\u{2B1C}\u{FE0F}"
            result += "\(status) \(reminder.title)"
            if let dueDate = reminder.dueDate {
                result += " (due: \(dueDate.formatted()))"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    func createReminder(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let title = args["title"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("title")
        }

        let notes = args["notes"]?.stringValue
        let listName = args["list"]?.stringValue
        let dueDateString = args["due_date"]?.stringValue

        var dueDate: Date?
        if let dateStr = dueDateString {
            dueDate = ISO8601DateFormatter().date(from: dateStr)
        }

        let reminder = TheaReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            listName: listName
        )
        _ = try await RemindersIntegration.shared.createReminder(reminder)

        return [.text("Created reminder: \(title)")]
    }

    func searchNotes(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let query = args["query"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("query")
        }

        let notes = try await NotesIntegration.shared.searchNotes(text: query)
        var result = "Found \(notes.count) notes:\n"
        for note in notes.prefix(10) {
            result += "- \(note.title)"
            if let folder = note.folderName {
                result += " (in \(folder))"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    func createNote(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let title = args["title"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("title")
        }
        guard let body = args["body"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("body")
        }

        let folder = args["folder"]?.stringValue

        _ = try await NotesIntegration.shared.createNote(title: title, body: body, folderName: folder)
        return [.text("Created note: \(title)")]
    }

    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    func searchLocation(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let query = args["query"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("query")
        }

        let criteria = LocationSearchCriteria(query: query)
        let results = try await MapsIntegration.shared.searchLocations(criteria: criteria)
        var result = "Found \(results.count) locations:\n"
        for location in results.prefix(5) {
            result += "- \(location.name)"
            if !location.address.isEmpty {
                result += ", \(location.address)"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    func getDirections(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let from = args["from"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("from")
        }
        guard let to = args["to"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("to")
        }

        let modeString = args["mode"]?.stringValue ?? "driving"
        let transportType: TransportType = switch modeString {
        case "walking": .walking
        case "transit": .transit
        default: .automobile
        }

        let routes = try await MapsIntegration.shared.getDirections(
            from: from,
            to: to,
            transportType: transportType
        )

        guard let route = routes.first else {
            return [.text("No routes found from \(from) to \(to)")]
        }

        var result = "Route from \(from) to \(to):\n"
        result += "Distance: \(route.distanceFormatted)\n"
        result += "Expected time: \(route.travelTimeFormatted)\n"
        result += "\nSteps:\n"
        for (index, step) in route.steps.enumerated() {
            if !step.instructions.isEmpty {
                result += "\(index + 1). \(step.instructions)\n"
            }
        }
        return [.text(result)]
    }

    func runShortcut(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let name = args["name"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("name")
        }

        let input = args["input"]?.stringValue ?? ""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name, "--input-path", "-"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe

        try process.run()
        inputPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return [.text("Shortcut '\(name)' completed.\n\(output)")]
    }

    func speak(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let text = args["text"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("text")
        }

        try await VoiceIntegration.shared.speak(text: text)
        return [.text("Speaking: \(text)")]
    }
}

#endif
