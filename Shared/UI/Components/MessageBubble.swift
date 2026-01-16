import SwiftUI

struct MessageBubble: View {
  let message: Message

  var body: some View {
    HStack {
      if message.messageRole == .user {
        Spacer()
      }

      VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: 4) {
        Text(message.content.textValue)
          .font(.theaBody)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(backgroundColor)
          .foregroundStyle(foregroundColor)
          .clipShape(RoundedRectangle(cornerRadius: 16))

        // Metadata
        HStack(spacing: 8) {
          if let model = message.model {
            Text(model)
              .font(.theaCaption2)
              .foregroundStyle(.secondary)
          }

          Text(message.timestamp, format: .dateTime.hour().minute())
            .font(.theaCaption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
      }

      if message.messageRole == .assistant {
        Spacer()
      }
    }
  }

  private var backgroundColor: Color {
    switch message.messageRole {
    case .user:
      return .theaPrimary
    case .assistant:
      #if os(macOS)
        return Color(nsColor: .systemGray)
      #else
        return Color(uiColor: .systemGray6)
      #endif
    case .system:
      #if os(macOS)
        return Color(nsColor: .systemGray)
      #else
        return Color(uiColor: .systemGray5)
      #endif
    }
  }

  private var foregroundColor: Color {
    switch message.messageRole {
    case .user:
      return .white
    case .assistant, .system:
      return .primary
    }
  }
}
