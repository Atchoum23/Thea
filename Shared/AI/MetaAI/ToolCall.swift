import Foundation
@preconcurrency import SwiftData

// MARK: - Tool Call Model
// Tracks tool execution for messages

@Model
final class ToolCall {
    var id = UUID()
    var toolName: String = ""
    var parameters: String = ""
    var result: String = ""
    var error: String?
    var success: Bool = false
    var startTime = Date()
    var endTime: Date?
    var messageId: UUID?
    
    init(toolName: String, parameters: String, messageId: UUID? = nil) {
        self.id = UUID()
        self.toolName = toolName
        self.parameters = parameters
        self.messageId = messageId
        self.startTime = Date()
    }
    
    func complete(result: String, success: Bool, error: String? = nil) {
        self.result = result
        self.success = success
        self.error = error
        self.endTime = Date()
    }
    
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
    
    var info: ToolCallInfo {
        ToolCallInfo(
            id: id,
            toolName: toolName,
            parameters: parameters,
            result: result,
            error: error,
            status: endTime == nil ? .running : (success ? .success : .failure),
            startTime: startTime,
            endTime: endTime
        )
    }
}
