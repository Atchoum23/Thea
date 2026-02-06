import SwiftUI

struct WelcomeView: View {
    var onSuggestionSelected: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xxxl) {
            Spacer()

            // Greeting
            VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                Text(Self.timeBasedGreeting())
                    .font(.theaLargeDisplay)
                    .foregroundStyle(Color.theaPrimaryGradientDefault)

                Text("How can I help you today?")
                    .font(.theaTitle2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, TheaSpacing.xxl)

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
            .padding(.horizontal, TheaSpacing.xxl)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
