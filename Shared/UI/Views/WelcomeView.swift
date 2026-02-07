import SwiftUI

struct WelcomeView: View {
    var onSuggestionSelected: ((String) -> Void)?

    @State private var spiralRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: TheaSpacing.xl) {
            Spacer()

            // Thea spiral icon with subtle idle spin — centered
            TheaSpiralIconView(size: 72, isThinking: false, showGlow: true)
                .rotationEffect(.degrees(spiralRotation))

            // Greeting with Thea's golden spiral brand colors — centered
            VStack(spacing: TheaSpacing.sm) {
                Text(Self.timeBasedGreeting())
                    .font(.theaLargeDisplay)
                    .foregroundStyle(TheaBrandColors.spiralGradient)

                Text("How can I help you today?")
                    .font(.theaTitle2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Self.timeBasedGreeting()) How can I help you today?")

            // Suggestion chips
            SuggestionChipGrid { item in
                if let onSuggestionSelected {
                    onSuggestionSelected(item.prompt)
                } else {
                    NotificationCenter.default.post(
                        name: Notification.Name.newConversation,
                        object: item.prompt
                    )
                }
            }
            .padding(.horizontal, TheaSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            // Very slow, subtle rotation — one full turn per minute
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                spiralRotation = 360
            }
        }
    }

    static func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning."
        case 12..<17:
            return "Good afternoon."
        case 17..<22:
            return "Good evening."
        default:
            return "Hello."
        }
    }
}

#Preview {
    WelcomeView()
}
