import SwiftUI

// MARK: - Tool Call View
// Displays information about a tool call with expandable details

struct ToolCallView: View {
    let toolCall: ToolCallInfo
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                statusIcon
                
                Text(toolCall.toolName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(toolCall.duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Parameters
                    if !toolCall.parameters.isEmpty {
                        Text("Parameters:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(toolCall.parameters)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(codeBackgroundColor)
                                .cornerRadius(4)
                        }
                    }
                    
                    // Result
                    if !toolCall.result.isEmpty {
                        Text("Result:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(toolCall.result)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(codeBackgroundColor)
                                .cornerRadius(4)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 200)
                    }
                    
                    // Error
                    if let error = toolCall.error {
                        Text("Error:")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: some View {
        Group {
            switch toolCall.status {
            case .running:
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var backgroundColor: Color {
        #if os(macOS)
        switch toolCall.status {
        case .running: return Color(nsColor: .controlBackgroundColor)
        case .success: return Color.green.opacity(0.05)
        case .failure: return Color.red.opacity(0.05)
        }
        #else
        switch toolCall.status {
        case .running: return Color(uiColor: .systemBackground)
        case .success: return Color.green.opacity(0.05)
        case .failure: return Color.red.opacity(0.05)
        }
        #endif
    }
    
    private var borderColor: Color {
        switch toolCall.status {
        case .running: return Color.blue
        case .success: return Color.green
        case .failure: return Color.red
        }
    }
    
    private var codeBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

// MARK: - Tool Call Info Model

struct ToolCallInfo: Identifiable, Sendable {
    let id: UUID
    let toolName: String
    let parameters: String
    let result: String
    let error: String?
    let status: ToolCallStatus
    let startTime: Date
    let endTime: Date?
    
    var duration: String {
        guard let end = endTime else { return "..." }
        let interval = end.timeIntervalSince(startTime)
        if interval < 1.0 {
            return String(format: "%.0fms", interval * 1000)
        } else {
            return String(format: "%.2fs", interval)
        }
    }
    
    enum ToolCallStatus: Sendable {
        case running, success, failure
    }
    
    init(
        id: UUID = UUID(),
        toolName: String,
        parameters: String,
        result: String = "",
        error: String? = nil,
        status: ToolCallStatus = .running,
        startTime: Date = Date(),
        endTime: Date? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.parameters = parameters
        self.result = result
        self.error = error
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ToolCallView(toolCall: ToolCallInfo(
            toolName: "file_read",
            parameters: #"{"path": "/Users/user/document.txt"}"#,
            result: "Lorem ipsum dolor sit amet...",
            status: .success,
            endTime: Date()
        ))
        
        ToolCallView(toolCall: ToolCallInfo(
            toolName: "terminal",
            parameters: #"{"command": "ls -la"}"#,
            status: .running
        ))
        
        ToolCallView(toolCall: ToolCallInfo(
            toolName: "web_search",
            parameters: #"{"query": "Swift concurrency"}"#,
            result: "",
            error: "Network connection failed",
            status: .failure,
            endTime: Date()
        ))
    }
    .padding()
    .frame(width: 500)
}
