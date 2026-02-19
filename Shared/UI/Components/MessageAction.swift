// MARK: - Message Action Enum

/// All possible actions on a message/turn
enum MessageAction {
    case copy
    case copyAsMarkdown
    // periphery:ignore - Reserved: copyAsMarkdown case reserved for future feature activation
    case edit
    case regenerate
    case rewrite(RewriteStyle)
    case retryWithModel(String)
    case continueFromHere
    case splitConversation
    case readAloud
    case shareMessage
    case pinMessage
    case selectText
    case deleteMessage

    /// Rewrite styles for assistant responses
    enum RewriteStyle: String, CaseIterable {
        case shorter
        case longer
        case simpler
        case moreDetailed
        case moreFormal
        case moreCasual

        // periphery:ignore - Reserved: label property reserved for future feature activation
        var label: String {
            switch self {
            case .shorter: "Shorter"
            case .longer: "Longer"
            case .simpler: "Simpler"
            case .moreDetailed: "More detailed"
            case .moreFormal: "More formal"
            case .moreCasual: "More casual"
            }
        }
    }
}
