import SwiftUI

struct ChatInputView: View {
  @Binding var text: String
  let isStreaming: Bool
  let onSend: () -> Void

  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(alignment: .bottom, spacing: 12) {
      // Text input
      TextField("Message THEA...", text: $text, axis: .vertical)
        .textFieldStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        #if os(macOS)
          .background(Color(nsColor: .systemGray))
        #else
          .background(Color(uiColor: .systemGray6))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .lineLimit(1...10)
        .focused($isFocused)
        .disabled(isStreaming)
        .onSubmit {
          if !text.isEmpty {
            onSend()
          }
        }

      // Send button
      Button {
        onSend()
      } label: {
        Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
          .font(.system(size: 32))
          .foregroundStyle(canSend ? Color.theaPrimary : .secondary)
      }
      .buttonStyle(.plain)
      .disabled(!canSend && !isStreaming)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .onAppear {
      isFocused = true
    }
  }

  private var canSend: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

#Preview {
  VStack {
    Spacer()
    ChatInputView(text: .constant(""), isStreaming: false) {
      print("Send")
    }
  }
}
