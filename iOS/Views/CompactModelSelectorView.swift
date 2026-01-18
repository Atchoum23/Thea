import SwiftUI

/// Compact model selector for chat input (iOS-specific version)
struct iOSCompactModelSelectorView: View {
    @Binding var selectedModel: String
    let availableModels: [String]
    
    var body: some View {
        Menu {
            ForEach(availableModels, id: \.self) { model in
                Button {
                    selectedModel = model
                } label: {
                    HStack {
                        Text(model)
                        if model == selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption)
                Text(selectedModel)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            #if os(iOS)
            .background(Color(uiColor: .systemGray6))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .clipShape(Capsule())
        }
    }
}

#Preview {
    iOSCompactModelSelectorView(
        selectedModel: .constant("GPT-4"),
        availableModels: ["GPT-4", "GPT-3.5", "Claude", "Llama"]
    )
}
