import SwiftUI

struct WelcomeView: View {
    var onSuggestionSelected: ((String) -> Void)?

    var body: some View {
        VStack(spacing: TheaSpacing.xl) {
            Spacer()

            // Thea spiral icon — extracted spiral (no background) with CCW rotation + beat
            TheaSpiralIconView(size: 80, isThinking: false, showGlow: true)

            // Greeting with Thea's golden spiral brand colors
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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12:
            return "Good morning."
        case 12 ..< 17:
            return "Good afternoon."
        case 17 ..< 22:
            return "Good evening."
        default:
            return "Hello."
        }
    }
}

#Preview {
    WelcomeView()
}
